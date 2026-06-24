# Deterministic post path helper for Sean's TidyTuesday date semantics.

tt_post_paths <- function(date, slug, root = ".") {
  if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", date)) {
    stop("date must use YYYY-MM-DD", call. = FALSE)
  }
  if (!grepl("^[a-z0-9]+(?:-[a-z0-9]+)*$", slug)) {
    stop("slug must be lowercase kebab-case", call. = FALSE)
  }

  post_slug <- paste(date, slug, sep = "-")
  post_dir <- file.path(root, "posts", post_slug)

  list(
    slug = post_slug,
    dir = post_dir,
    qmd = file.path(post_dir, paste0(post_slug, ".qmd")),
    freeze = file.path(root, "_freeze", "posts", post_slug),
    docs = file.path(root, "docs", "posts", post_slug)
  )
}
