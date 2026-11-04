#!/usr/bin/env Rscript

# Scaffold one compact Quarto post per official 30DayMapChallenge theme.
# Intentionally uses only base R: theme intake should be deterministic.

abort <- function(message) stop(message, call. = FALSE)

args <- commandArgs(trailingOnly = TRUE)
read_arg <- function(flag) {
  index <- match(flag, args)
  if (is.na(index) || index == length(args)) abort(sprintf("Missing value for %s", flag))
  args[[index + 1]]
}

if (identical(args, "--help") || identical(args, "-h")) {
  cat("Usage: Rscript scripts/scaffold_30day_map_challenge.R --themes PATH --posts-root posts\n")
  quit(status = 0)
}

themes_path <- read_arg("--themes")
posts_root <- read_arg("--posts-root")

if (!file.exists(themes_path)) abort(sprintf("Themes file does not exist: %s", themes_path))
themes <- utils::read.csv(themes_path, stringsAsFactors = FALSE, check.names = FALSE)
required_columns <- c("day", "theme", "package_lane", "data_idea", "fallback")
missing_columns <- setdiff(required_columns, names(themes))
if (length(missing_columns)) abort(sprintf("Themes CSV is missing required column(s): %s", paste(missing_columns, collapse = ", ")))

if (nrow(themes) != 30L) abort(sprintf("Expected exactly 30 theme rows; found %d", nrow(themes)))
if (!identical(sort(as.integer(themes$day)), 1:30)) abort("`day` must contain each integer from 1 through 30 exactly once.")
if (anyNA(themes$theme) || any(!nzchar(trimws(themes$theme))) || any(grepl("REPLACE WITH OFFICIAL THEME", themes$theme, fixed = TRUE))) {
  abort("Every row needs an official theme before scaffolding.")
}
if (anyDuplicated(tolower(trimws(themes$theme)))) abort("Theme labels must be unique.")

slugify <- function(x) {
  x <- tolower(trimws(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9]+", "-", x)
  x <- gsub("(^-+|-+$)", "", x)
  if (!nzchar(x)) abort("A theme could not be converted into a filesystem-safe slug.")
  x
}

escape_yaml <- function(x) gsub('"', '\\"', x, fixed = TRUE)
post_template <- function(day, theme, lane, data_idea, fallback) {
  title <- sprintf("30 Day Map Challenge — Day %02d: %s", day, theme)
  c(
    "---",
    sprintf('title: "%s"', escape_yaml(title)),
    'author: "Sean Thimons"',
    sprintf('date: "2026-11-%02d"', day),
    sprintf('description: "A 30 Day Map Challenge 2026 map for the theme: %s."', escape_yaml(theme)),
    "categories:",
    "  - cartography",
    "  - R",
    "  - 30DayMapChallenge",
    sprintf("  - %s", lane),
    "draft: true",
    "---",
    "",
    "```{r}",
    "#| label: setup",
    "#| message: false",
    "#| warning: false",
    "",
    "# Add only the packages used for this map. Keep package installation out of the post.",
    "library(sf)",
    "```",
    "",
    sprintf("# Day %02d — %s", day, theme),
    "",
    "<!-- Replace this callout with the finished map immediately before publication. -->",
    "::: {.callout-note}",
    "Map in progress.",
    ":::",
    "",
    "## The geographic question",
    "",
    "Write one paragraph explaining what this map is trying to make visible.",
    "",
    "## Data & provenance",
    "",
    sprintf("- Data idea: %s", data_idea),
    "- Source URL: TODO",
    "- Retrieved: TODO",
    "- License/terms: TODO",
    "- CRS/projection: TODO",
    "",
    "## Method",
    "",
    sprintf("- Package lane: `%s`", lane),
    "- Map type: TODO",
    "- Classification/scale: TODO",
    "- Cartographic choice: TODO",
    "",
    "```{r}",
    "#| label: map",
    "#| fig-alt: 'TODO: describe the map, geography, visual encodings, and main pattern.'",
    "",
    "# Reproducible data preparation and map construction go here.",
    "```",
    "",
    "## What I learned",
    "",
    "One short note about the package, data, or cartographic trade-off.",
    "",
    "## Fallback",
    "",
    fallback,
    "",
    "---",
    "",
    "*Created for #30DayMapChallenge. Data and cartographic sources are credited above.*"
  )
}

dir.create(posts_root, recursive = TRUE, showWarnings = FALSE)
themes <- themes[order(themes$day), ]
created <- character()
for (i in seq_len(nrow(themes))) {
  day <- as.integer(themes$day[[i]])
  slug <- slugify(themes$theme[[i]])
  folder <- file.path(posts_root, sprintf("2026-11-%02d-30daymap-%02d-%s", day, day, slug))
  qmd <- file.path(folder, sprintf("2026-11-%02d-30daymap-%02d-%s.qmd", day, day, slug))
  if (dir.exists(folder) || file.exists(qmd)) abort(sprintf("Refusing to overwrite existing post path: %s", folder))
  dir.create(folder, recursive = TRUE)
  writeLines(post_template(day, themes$theme[[i]], themes$package_lane[[i]], themes$data_idea[[i]], themes$fallback[[i]]), qmd, useBytes = TRUE)
  created <- c(created, qmd)
}

cat(sprintf("Created %d draft post(s):\n", length(created)))
cat(paste0("- ", created, collapse = "\n"), "\n")
