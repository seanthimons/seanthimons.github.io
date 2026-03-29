library(paletteer)
all_colors <- paletteer::paletteer_d("MexBrewer::Atentado", n = 10)
cat("All 10 Atentado colors:\n")
for (i in seq_along(all_colors)) {
  cat(sprintf("  [%d]: %s\n", i, all_colors[i]))
}
