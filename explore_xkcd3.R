options(timeout = 120)
library(dplyr)

base_url <- "https://raw.githubusercontent.com/rfordatascience/tidytuesday/main/data/2025/2025-07-08"
color_ranks <- read.csv(file.path(base_url, "color_ranks.csv"))
users       <- read.csv(file.path(base_url, "users.csv"))
answers     <- read.csv(file.path(base_url, "answers.csv"))

# Convert hex to RGB then HSL
hex_to_hsl <- function(hex_vec) {
  rgb_mat <- col2rgb(hex_vec) / 255
  r <- rgb_mat[1, ]; g <- rgb_mat[2, ]; b <- rgb_mat[3, ]
  cmax <- pmax(r, g, b); cmin <- pmin(r, g, b)
  delta <- cmax - cmin
  l <- (cmax + cmin) / 2
  s <- ifelse(delta == 0, 0, delta / (1 - abs(2*l - 1)))
  h <- ifelse(delta == 0, 0,
    ifelse(cmax == r, 60 * (((g - b)/delta) %% 6),
    ifelse(cmax == g, 60 * ((b - r)/delta + 2),
                      60 * ((r - g)/delta + 4))))
  h <- ifelse(h < 0, h + 360, h)
  data.frame(h = h, s = s, l = l)
}

# Filter spam users
clean_users <- users[!is.na(users$spam_prob) & users$spam_prob < 0.5, "user_id", drop = FALSE]
merged <- merge(answers, clean_users, by = "user_id")
cat("Non-spam answers:", nrow(merged), "\n")

# For each hex, find the most common rank (plurality vote)
cat("Computing plurality vote per hex color...\n")
plurality <- merged %>%
  group_by(hex, rank) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(hex) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup()

cat("Unique hex colors with plurality vote:", nrow(plurality), "\n")
cat("Distribution of plurality ranks:\n")
print(table(plurality$rank))

# Join with color names (using top5 from color_ranks)
top5 <- color_ranks[color_ranks$rank %in% 1:5, ]
top5 <- top5[, c("rank", "color", "hex")]
names(top5) <- c("rank", "color_name", "canonical_hex")
plurality <- merge(plurality, top5, by = "rank")

cat("\nPlurality vote breakdown by color_name:\n")
print(table(plurality$color_name))

# Convert to HSL
cat("\nConverting to HSL...\n")
hsl <- hex_to_hsl(plurality$hex)
plurality <- cbind(plurality, hsl)
cat("Done\n")
cat("HSL sample:\n")
print(head(plurality, 5))

# Hue ranges per color
for (cn in c("blue", "purple", "green", "pink", "brown")) {
  sub <- plurality[plurality$color_name == cn, ]
  cat(sprintf("\n%s: n=%d, H=[%.1f, %.1f], S=[%.2f, %.2f], L=[%.2f, %.2f]\n",
    cn, nrow(sub),
    min(sub$h), max(sub$h),
    min(sub$s), max(sub$s),
    min(sub$l), max(sub$l)
  ))
}

saveRDS(plurality, "plurality_hsl.rds")
cat("\nSaved. Total rows:", nrow(plurality), "\n")
