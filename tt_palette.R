options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("paletteer", quietly = TRUE)) install.packages("paletteer")
if (!requireNamespace("scico", quietly = TRUE)) install.packages("scico")
if (!requireNamespace("rockthemes", quietly = TRUE)) install.packages("rockthemes")

library(paletteer)

# Check scico bamako
cat("=== scico::bamako (continuous) ===\n")
p <- paletteer::paletteer_c("scico::bamako", n = 10)
print(p)

# Check rockthemes palettes
cat("\n=== rockthemes palettes ===\n")
rt_pals <- paletteer::palettes_d_names %>% dplyr::filter(package == "rockthemes")
print(rt_pals)

# Preview a few
for (pal in c("acdc", "beatles", "nirvana", "radiohead")) {
  tryCatch({
    p <- paletteer::paletteer_d(paste0("rockthemes::", pal))
    cat(sprintf("\nrockthemes::%s (%d colors): %s\n", pal, length(p), paste(p, collapse=", ")))
  }, error = function(e) cat(sprintf("Error with %s: %s\n", pal, e$message)))
}
