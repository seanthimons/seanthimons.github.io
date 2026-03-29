options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("tidytuesdayR", quietly = TRUE)) {
  install.packages("tidytuesdayR")
}
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}

library(tidytuesdayR)
library(dplyr)

cat("Loading 2025-08-26 dataset...\n")
raw <- tidytuesdayR::tt_load("2025-08-26")
cat("Datasets:", paste(names(raw), collapse=", "), "\n\n")

for (nm in names(raw)) {
  df <- raw[[nm]]
  cat(sprintf("=== %s: %d rows x %d cols ===\n", nm, nrow(df), ncol(df)))
  cat("Columns:", paste(names(df), collapse=", "), "\n")
  cat("Column types:\n")
  print(sapply(df, class))
  cat("\nHead (10 rows):\n")
  print(head(df, 10))
  cat("\n")
}
