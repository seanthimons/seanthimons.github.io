args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else getwd()
out <- file.path(script_dir, "palette-swatches.png")
png(out, width = 1600, height = 1200, res = 150, type = "cairo")
par(mar = c(0, 0, 0, 0), bg = "#FFFFFF", family = "sans")
plot.new()
plot.window(xlim = c(0, 1600), ylim = c(0, 1200), xaxs = "i", yaxs = "i")
text(70, 1135, "DAY 02 / PALETTE STUDIES", adj = 0, cex = 1.7, col = "#263B43", font = 2)
text(70, 1080, "Paper + contour ink. Right panel previews fine line contrast.", adj = 0, cex = 1, col = "#626666")
palettes <- list(
  list(name = "Limestone & ink", bg = "#F5F1E8", ink = "#263B43", note = "Recommended / warm paper, cool blue-black"),
  list(name = "Iron oxide", bg = "#F7F0E5", ink = "#804737", note = "Warm / geological engraving"),
  list(name = "Night survey", bg = "#18282D", ink = "#D3CDBB", note = "Dark / pale mineral linework")
)
for (i in seq_along(palettes)) {
  p <- palettes[[i]]
  top <- 985 - (i - 1) * 320
  text(70, top, p$name, adj = 0, cex = 1.5, font = 2, col = "#263B43")
  text(70, top - 40, p$note, adj = 0, cex = 0.95, col = "#626666")
  y0 <- top - 245
  rect(70, y0, 550, top - 70, col = p$bg, border = "#D6D6D2")
  rect(550, y0, 800, top - 70, col = p$ink, border = NA)
  rect(850, y0, 1530, top - 70, col = p$bg, border = "#D6D6D2")
  xx <- seq(850, 1530, length.out = 500)
  for (j in seq_len(13)) {
    yy <- y0 + 8 + j * 11 + 15 * sin((xx - 850) / 100 + j * 0.12)
    lines(xx, yy, col = p$ink, lwd = 0.65)
  }
  text(70, y0 - 22, "BACKGROUND", adj = 0, cex = 0.7, col = "#626666")
  text(550, y0 - 22, "CONTOURS", adj = 0, cex = 0.7, col = "#626666")
}
dev.off()
cat(out, "\n")
