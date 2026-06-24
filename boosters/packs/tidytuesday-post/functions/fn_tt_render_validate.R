# Render and validate a TidyTuesday post using the blog's existing quality gate.

tt_render_validate <- function(slug, qmd = NULL, root = ".", execute = TRUE) {
  if (is.null(qmd)) {
    qmd <- file.path(root, "posts", slug, paste0(slug, ".qmd"))
  }

  args <- c("render", qmd)
  if (isTRUE(execute)) {
    args <- c(args, "--execute")
  }

  render_status <- system2("quarto", args, stdout = TRUE, stderr = TRUE)
  render_code <- attr(render_status, "status") %||% 0L
  if (!identical(as.integer(render_code), 0L)) {
    stop(paste(render_status, collapse = "\n"), call. = FALSE)
  }

  validation <- system2(
    "Rscript",
    c(file.path(root, "scripts", "validate_post.R"), slug),
    stdout = TRUE,
    stderr = TRUE
  )
  validation_code <- attr(validation, "status") %||% 0L
  if (!identical(as.integer(validation_code), 0L)) {
    stop(paste(validation, collapse = "\n"), call. = FALSE)
  }

  invisible(list(render = render_status, validation = validation))
}
