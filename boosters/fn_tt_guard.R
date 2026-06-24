# Guard helpers for TidyTuesday post data.

#' Require a data frame-like object to have at least `min_rows` rows.
tt_require_rows <- function(x, name = deparse(substitute(x)), min_rows = 1L) {
  if (is.null(x) || is.null(dim(x))) {
    stop(name, " is not a data frame-like object", call. = FALSE)
  }

  rows <- nrow(x)
  if (is.na(rows) || rows < min_rows) {
    stop(name, " has fewer than ", min_rows, " row(s).", call. = FALSE)
  }

  invisible(x)
}

#' Require a data frame-like object to include named columns.
tt_require_cols <- function(x, cols, name = deparse(substitute(x))) {
  if (is.null(x) || is.null(names(x))) {
    stop(name, " is not a named data frame-like object", call. = FALSE)
  }

  missing <- setdiff(cols, names(x))
  if (length(missing) > 0) {
    stop(
      name,
      " is missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(x)
}
