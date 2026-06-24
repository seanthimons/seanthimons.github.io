# Project-local booster attachment for TidyTuesday blog posts.
# This file is intentionally plain R so posts can render even before boosterpak
# grows first-class template/status support.

.local_booster_install_missing <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0) {
    return(invisible(character()))
  }

  auto_install <- !identical(tolower(Sys.getenv("BOOSTERPAK_AUTO_INSTALL", "true")), "false")
  if (!isTRUE(auto_install)) {
    stop(
      "Missing required package(s): ", paste(missing, collapse = ", "),
      ". Set BOOSTERPAK_AUTO_INSTALL=true or install them before rendering.",
      call. = FALSE
    )
  }

  if (!requireNamespace("pak", quietly = TRUE)) {
    install.packages("pak", repos = "https://cloud.r-project.org")
  }
  pak::pkg_install(missing)
  invisible(missing)
}

.local_booster_attach <- function(packages) {
  .local_booster_install_missing(packages)
  invisible(lapply(packages, library, character.only = TRUE))
}

.local_booster_source <- function(files) {
  root <- if (requireNamespace("here", quietly = TRUE)) here::here() else getwd()
  invisible(lapply(file.path(root, "boosters", files), source))
}

.local_booster_packages <- c(
  "fs",
  "here",
  "janitor",
  "tidyverse",
  "skimr",
  "paletteer",
  "tidytuesdayR",
  "scales",
  "glue"
)

.local_booster_attach(.local_booster_packages)

.local_booster_source(c(
  "fn_tt_guard.R",
  "fn_tt_inventory.R",
  "fn_tt_load_clean.R",
  "fn_tt_palette.R",
  "fn_tt_post_paths.R",
  "fn_tt_render_validate.R",
  "fn_tt_theme.R"
))

`%ni%` <- Negate(`%in%`)

geometric_mean <- function(x) {
  exp(mean(log(x[x > 0]), na.rm = TRUE))
}

my_skim <- skimr::skim_with(
  numeric = skimr::sfl(
    n = length,
    min = ~ min(.x, na.rm = TRUE),
    p25 = ~ stats::quantile(., probs = .25, na.rm = TRUE, names = FALSE),
    med = ~ stats::median(.x, na.rm = TRUE),
    p75 = ~ stats::quantile(., probs = .75, na.rm = TRUE, names = FALSE),
    max = ~ max(.x, na.rm = TRUE),
    mean = ~ mean(.x, na.rm = TRUE),
    geo_mean = ~ geometric_mean(.x),
    sd = ~ stats::sd(., na.rm = TRUE),
    hist = ~ skimr::inline_hist(., 5)
  ),
  append = FALSE
)

rm(.local_booster_attach, .local_booster_install_missing, .local_booster_source, .local_booster_packages)
