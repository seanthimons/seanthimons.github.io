# TidyTuesday data loading helper.

tt_load_clean <- function(date, required = NULL, clean_names = TRUE) {
  if (!requireNamespace("tidytuesdayR", quietly = TRUE)) {
    stop("Package 'tidytuesdayR' is required for tt_load_clean().", call. = FALSE)
  }

  raw <- tidytuesdayR::tt_load(date)

  if (!is.null(required)) {
    missing <- setdiff(required, names(raw))
    if (length(missing) > 0) {
      stop(
        "Missing required TidyTuesday table(s): ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
  }

  if (isTRUE(clean_names)) {
    if (!requireNamespace("janitor", quietly = TRUE)) {
      stop("Package 'janitor' is required when clean_names = TRUE.", call. = FALSE)
    }
    raw <- lapply(raw, janitor::clean_names)
  }

  invisible(lapply(names(raw), function(nm) tt_require_rows(raw[[nm]], nm)))
  raw
}
