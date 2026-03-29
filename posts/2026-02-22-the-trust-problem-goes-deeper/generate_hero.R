# Generate hero image for this post
# Run from repo root: Rscript posts/2026-02-22-the-trust-problem-goes-deeper/generate_hero.R

source(here::here("hero_generator.R"))

palette <- list(
  bg        = "#FAF8F5",
  fg        = "#6F4E37",
  accent    = "#722F37",
  primary   = "#8B4513",
  secondary = "#CC7722"
)

generate_hero(
  algorithm   = "concentric_drift",
  palette     = palette,
  seed        = as.integer(as.Date("2026-02-22")),
  output_path = here::here(
    "posts",
    "2026-02-22-the-trust-problem-goes-deeper",
    "hero.png"
  ),
  width  = 10,
  height = 7
)

cat("Hero image generated.\n")
