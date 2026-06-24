# Sean's standard skimr profile for TidyTuesday exploratory data analysis.

.geometric_mean <- function(x) {
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
    geo_mean = ~ .geometric_mean(.x),
    sd = ~ stats::sd(., na.rm = TRUE),
    hist = ~ skimr::inline_hist(., 5)
  ),
  append = FALSE
)
