# Inventory helpers for loaded TidyTuesday tables.

tt_inventory <- function(x) {
  if (!is.list(x) || is.null(names(x))) {
    stop("tt_inventory() expects a named list of data frames", call. = FALSE)
  }

  out <- data.frame(
    table = names(x),
    rows = as.integer(vapply(x, nrow, integer(1))),
    columns = as.integer(vapply(x, ncol, integer(1))),
    fields = vapply(x, function(tbl) paste(names(tbl), collapse = ", "), character(1)),
    stringsAsFactors = FALSE
  )

  if (requireNamespace("tibble", quietly = TRUE)) {
    out <- tibble::as_tibble(out)
  }

  out
}
