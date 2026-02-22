#!/usr/bin/env Rscript
#
# validate_post.R — Post-render validation for Tidy Tuesday posts
#
# Parses the freeze JSON to detect empty/meaningless data in rendered output.
# Returns structured JSON diagnostics to stdout for the self-healing loop.
#
# Usage:
#   Rscript scripts/validate_post.R <post_slug>
#
# Exit codes:
#   0 = pass (all checks OK)
#   1 = fail (issues detected — diagnostics in stdout JSON)
#   2 = error (couldn't run validation)
#
# Example:
#   Rscript scripts/validate_post.R 2025-10-28-selected-british-literary-prizes
#

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  cat('{"status":"error","message":"Usage: validate_post.R <post_slug>"}\n')
  quit(status = 2)
}

post_slug <- args[1]
project_dir <- here::here()

# --- Locate freeze JSON ---
freeze_json_path <- file.path(
  project_dir, "_freeze", "posts", post_slug, post_slug,
  "execute-results", "html.json"
)

if (!file.exists(freeze_json_path)) {
  cat(sprintf(
    '{"status":"error","message":"Freeze JSON not found at %s"}\n',
    freeze_json_path
  ))
  quit(status = 2)
}

# --- Parse freeze JSON and extract markdown ---
freeze <- jsonlite::fromJSON(freeze_json_path, simplifyVector = FALSE)
md <- freeze$result$markdown

if (is.null(md) || nchar(md) < 100) {
  cat('{"status":"fail","issues":["Freeze markdown is empty or trivially short"]}\n')
  quit(status = 1)
}

issues <- character(0)

# --- Check 1: Empty tibbles (0-row dataframes printed in output) ---
empty_tibble_pattern <- "# A tibble: 0"
empty_tibble_matches <- gregexpr(empty_tibble_pattern, md, fixed = TRUE)[[1]]
n_empty_tibbles <- sum(empty_tibble_matches > 0)

if (n_empty_tibbles > 0) {
  # Extract context around each empty tibble for diagnostics
  positions <- as.integer(empty_tibble_matches[empty_tibble_matches > 0])
  contexts <- vapply(positions, function(pos) {
    # Grab ~300 chars before the empty tibble to find the code that produced it
    before <- substr(md, max(1, pos - 300), pos - 1)
    # Clean up for readable diagnostics
    before <- gsub("\\n", " | ", before)
    before <- substr(before, max(1, nchar(before) - 150), nchar(before))
    trimws(paste0("...context: ", before, " => produced 0 rows"))
  }, character(1))

  issues <- c(issues, paste0(
    "EMPTY_DATA: Found ", n_empty_tibbles, " zero-row tibble(s) in rendered output. ",
    paste(contexts, collapse = "; ")
  ))
}

# --- Check 2: Suspiciously uniform computed columns ---
# Look for tables where a percentage/proportion column is 100% for all rows
# Pattern: column of all 1s in a tibble (like pct_diverse = 1 for every row)
uniform_pattern <- "\\b(pct|percent|prop|ratio|share|rate)\\w*\\b"
# Find all tibble output blocks
tibble_blocks <- regmatches(
  md,
  gregexpr("# A tibble:.*?(?=\\n\\n|:::|$)", md, perl = TRUE)
)[[1]]

for (block in tibble_blocks) {
  lines <- strsplit(block, "\n")[[1]]
  # Skip header lines, look at data lines
  data_lines <- lines[grepl("^\\s*\\d+\\s", lines)]
  if (length(data_lines) >= 3) {
    # Check if any numeric column has identical values across all rows
    # Split each line and look for repeated values
    values_by_col <- tryCatch({
      # Parse as a simple space-separated table
      parsed <- lapply(data_lines, function(l) {
        parts <- trimws(strsplit(trimws(l), "\\s{2,}")[[1]])
        parts
      })
      # Transpose to get columns
      n_cols <- min(sapply(parsed, length))
      if (n_cols >= 2) {
        cols <- lapply(seq_len(n_cols), function(j) {
          sapply(parsed, function(row) if (j <= length(row)) row[j] else NA)
        })
        cols
      } else {
        NULL
      }
    }, error = function(e) NULL)

    if (!is.null(values_by_col)) {
      for (col_vals in values_by_col) {
        # Check if all values are the same number (especially 1, 0, or 100)
        nums <- suppressWarnings(as.numeric(col_vals))
        if (!any(is.na(nums)) && length(unique(nums)) == 1 && length(nums) >= 3) {
          val <- unique(nums)
          if (val %in% c(0, 1, 100)) {
            issues <- c(issues, paste0(
              "UNIFORM_VALUES: A computed column has the value ", val,
              " for all ", length(nums), " rows — likely a filter/logic bug. ",
              "First few data lines: ", paste(head(data_lines, 3), collapse = " | ")
            ))
          }
        }
      }
    }
  }
}

# --- Check 3: Plot images referenced but potentially empty ---
# Count figure references in the markdown
fig_refs <- regmatches(md, gregexpr("figure-html/[^)\"]+\\.png", md))[[1]]
n_figs <- length(fig_refs)

if (n_figs == 0) {
  issues <- c(issues, "NO_PLOTS: No plot images (figure-html/*.png) referenced in rendered output")
} else {
  # Check actual figure files on disk
  freeze_fig_dir <- file.path(
    project_dir, "_freeze", "posts", post_slug, post_slug, "figure-html"
  )
  if (dir.exists(freeze_fig_dir)) {
    pngs <- list.files(freeze_fig_dir, pattern = "\\.png$", full.names = TRUE)
    small_plots <- pngs[file.size(pngs) < 15000]  # <15KB is suspicious
    if (length(small_plots) > 0) {
      issues <- c(issues, paste0(
        "SMALL_PLOTS: ", length(small_plots), " of ", length(pngs),
        " plot image(s) are under 15KB (likely empty axes): ",
        paste(basename(small_plots), collapse = ", ")
      ))
    }
  }
}

# --- Check 4: R errors or warnings in output ---
error_patterns <- c(
  "Error in ", "Error:", "could not find function",
  "object '.+' not found", "unused argument",
  "Joining with `by = join_by\\(\\)`",  # accidental cross-join
  "no non-missing arguments to"
)
for (pat in error_patterns) {
  if (grepl(pat, md, perl = TRUE)) {
    match_ctx <- regmatches(md, regexpr(paste0(".{0,80}", pat, ".{0,80}"), md, perl = TRUE))
    issues <- c(issues, paste0(
      "R_ERROR: Found '", pat, "' in rendered output: ...",
      gsub("\\n", " ", substr(match_ctx, 1, 200)), "..."
    ))
  }
}

# --- Check 5: Minimum content threshold ---
# Strip code blocks and YAML, count narrative words
narrative <- gsub("```.*?```", "", md, perl = TRUE)
narrative <- gsub("---.*?---", "", narrative, perl = TRUE)
narrative <- gsub("#\\|.*", "", narrative)  # chunk options
word_count <- length(strsplit(trimws(narrative), "\\s+")[[1]])

if (word_count < 200) {
  issues <- c(issues, paste0(
    "THIN_CONTENT: Post has only ~", word_count,
    " words of narrative content (minimum: 200)"
  ))
}

# --- Check 6: Data loading produced rows ---
# Look for skim output — "Number of rows" should be > 0
skim_rows <- regmatches(md, regexpr("Number of rows\\s*\\|\\s*(\\d+)", md, perl = TRUE))
if (length(skim_rows) > 0) {
  row_count <- as.integer(sub(".*\\|\\s*(\\d+)", "\\1", skim_rows[1]))
  if (!is.na(row_count) && row_count == 0) {
    issues <- c(issues, "EMPTY_DATASET: skim() reports 0 rows — data loading likely failed")
  }
}

# --- Build result ---
if (length(issues) == 0) {
  result <- list(
    status = "pass",
    post_slug = post_slug,
    n_figures = n_figs,
    word_count = word_count,
    message = "All validation checks passed"
  )
  cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = FALSE))
  cat("\n")
  quit(status = 0)
} else {
  result <- list(
    status = "fail",
    post_slug = post_slug,
    n_figures = n_figs,
    word_count = word_count,
    n_issues = length(issues),
    issues = issues
  )
  cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = FALSE))
  cat("\n")
  quit(status = 1)
}
