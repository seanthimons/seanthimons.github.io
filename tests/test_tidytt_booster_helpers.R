#!/usr/bin/env Rscript

repo_root <- normalizePath(getwd(), mustWork = TRUE)

source(file.path(repo_root, "boosters", "fn_my_skim.R"), local = TRUE)
source(file.path(repo_root, "boosters", "fn_tt_guard.R"), local = TRUE)
source(file.path(repo_root, "boosters", "fn_tt_inventory.R"), local = TRUE)
source(file.path(repo_root, "boosters", "fn_tt_palette.R"), local = TRUE)
source(file.path(repo_root, "boosters", "fn_tt_post_paths.R"), local = TRUE)

expect_true <- function(x, msg) {
  if (!isTRUE(x)) stop(msg, call. = FALSE)
}

expect_error <- function(expr, pattern) {
  err <- tryCatch({
    force(expr)
    NULL
  }, error = identity)

  if (is.null(err)) stop("Expected error, got none", call. = FALSE)
  if (!grepl(pattern, conditionMessage(err))) {
    stop(sprintf("Expected error matching %s, got: %s", pattern, conditionMessage(err)), call. = FALSE)
  }
}

# my_skim should be a materialized booster function, not attach.R-only glue.
expect_true(exists("my_skim"), "my_skim should be sourced from boosters/fn_my_skim.R")
skimmed <- my_skim(data.frame(a = c(1, 2, 4), b = c("x", "y", NA)))
expect_true(any(names(skimmed) == "numeric.geo_mean"), "my_skim should include geometric mean output")

# Guard helpers fail closed on empty data and missing required columns.
non_empty <- data.frame(a = 1:2, b = c("x", "y"))
empty <- non_empty[0, ]

expect_true(identical(tt_require_rows(non_empty, "non_empty"), non_empty), "tt_require_rows should invisibly return input")
expect_error(tt_require_rows(empty, "empty"), "fewer than 1 row")
expect_true(identical(tt_require_cols(non_empty, c("a", "b"), "non_empty"), non_empty), "tt_require_cols should invisibly return input")
expect_error(tt_require_cols(non_empty, c("a", "c"), "non_empty"), "missing required column")

# Inventory should summarize named tables deterministically.
inv <- tt_inventory(list(first = non_empty, second = data.frame(x = 1:3)))
expect_true(identical(inv$table, c("first", "second")), "tt_inventory should preserve names")
expect_true(identical(inv$rows, c(2L, 3L)), "tt_inventory should report row counts")
expect_true(identical(inv$columns, c(2L, 1L)), "tt_inventory should report column counts")

# Palette helper should preserve provenance attributes for downstream hero/logging helpers.
pal <- tt_palette_manual(c("#111111", "#222222"), source = "manual", name = "unit-test", type = "discrete")
expect_true(identical(as.character(pal), c("#111111", "#222222")), "manual palette should keep color vector")
expect_true(identical(attr(pal, "source"), "manual"), "manual palette should store source")
expect_true(identical(attr(pal, "name"), "unit-test"), "manual palette should store name")
expect_true(identical(attr(pal, "type"), "discrete"), "manual palette should store type")
expect_true(identical(attr(pal, "id"), "manual::unit-test"), "manual palette should store id")

# Post path helper should encode Sean's TidyTuesday date semantics.
paths <- tt_post_paths("2026-06-23", "papal-encyclicals-industrial-revolution-vs-ai-revolution", root = ".")
expect_true(identical(paths$slug, "2026-06-23-papal-encyclicals-industrial-revolution-vs-ai-revolution"), "slug should date-prefix")
expect_true(identical(paths$qmd, file.path(".", "posts", paths$slug, paste0(paths$slug, ".qmd"))), "qmd path should be deterministic")
expect_error(tt_post_paths("2026/06/23", "bad-date"), "YYYY-MM-DD")

cat("tidytuesday booster helper tests passed\n")
