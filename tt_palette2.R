options(repos = c(CRAN = "https://cloud.r-project.org"))
library(paletteer)

# Check MexBrewer palettes (Alacena is used, need others)
cat("=== MexBrewer palettes ===\n")
mb <- paletteer::palettes_d_names[paletteer::palettes_d_names$package == "MexBrewer", ]
print(mb)

# Preview some with 4+ colors
for (pal in c("Tierra", "Animas", "Atentado", "Frida", "Revolucion")) {
  tryCatch({
    p <- paletteer::paletteer_d(paste0("MexBrewer::", pal))
    cat(sprintf("\nMexBrewer::%s (%d colors)\n", pal, length(p)))
  }, error = function(e) cat(sprintf("Error %s: %s\n", pal, e$message)))
}

# Check lisa palettes
cat("\n=== lisa palettes (sample) ===\n")
lisa_p <- paletteer::palettes_d_names[paletteer::palettes_d_names$package == "lisa", ]
print(head(lisa_p, 30))

# Check harrypotter
cat("\n=== harrypotter palettes ===\n")
hp <- paletteer::palettes_d_names[paletteer::palettes_d_names$package == "harrypotter", ]
print(hp)
