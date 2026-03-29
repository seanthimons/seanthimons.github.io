options(timeout = 120)

base_url <- "https://raw.githubusercontent.com/rfordatascience/tidytuesday/main/data/2025/2025-07-08"

cat("Loading answers...\n")
answers <- read.csv(file.path(base_url, "answers.csv"))
cat(sprintf("answers: %d rows x %d cols\n", nrow(answers), ncol(answers)))
cat("Cols:", paste(names(answers), collapse=", "), "\n")
print(head(answers, 3))

cat("\nLoading color_ranks...\n")
color_ranks <- read.csv(file.path(base_url, "color_ranks.csv"))
cat(sprintf("color_ranks: %d rows x %d cols\n", nrow(color_ranks), ncol(color_ranks)))
cat("Cols:", paste(names(color_ranks), collapse=", "), "\n")
print(head(color_ranks, 3))

cat("\nLoading users...\n")
users <- read.csv(file.path(base_url, "users.csv"))
cat(sprintf("users: %d rows x %d cols\n", nrow(users), ncol(users)))
cat("Cols:", paste(names(users), collapse=", "), "\n")
print(head(users, 3))

cat("\n=== users summary ===\n")
print(lapply(users, function(x) {
  if (is.character(x) || is.factor(x)) table(x)
  else summary(x)
}))
