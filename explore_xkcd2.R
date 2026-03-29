options(timeout = 120)
base_url <- "https://raw.githubusercontent.com/rfordatascience/tidytuesday/main/data/2025/2025-07-08"

color_ranks <- read.csv(file.path(base_url, "color_ranks.csv"))
users       <- read.csv(file.path(base_url, "users.csv"))
answers     <- read.csv(file.path(base_url, "answers.csv"))

cat("=== Top 20 colors by rank ===\n")
top20 <- color_ranks[order(color_ranks$rank), ][1:20, ]
print(top20)

cat("\n=== Rank distribution in answers ===\n")
print(summary(answers$rank))
cat("Median rank:", median(answers$rank), "\n")

cat("\n=== Join: avg rank by colorblind status ===\n")
# Only use non-spam users (spam_prob < 0.5)
clean_users <- users[users$spam_prob < 0.5, ]
merged <- merge(answers, clean_users, by = "user_id")
cat("Merged rows:", nrow(merged), "\n")

by_colorblind <- aggregate(rank ~ colorblind, data = merged[!is.na(merged$colorblind), ], FUN = median)
print(by_colorblind)

by_sex <- aggregate(rank ~ y_chromosome, data = merged[!is.na(merged$y_chromosome), ], FUN = median)
print(by_sex)

by_monitor <- aggregate(rank ~ monitor, data = merged, FUN = median)
print(by_monitor)

cat("\n=== Colorblind proportions ===\n")
cat("Overall colorblind rate:", mean(users$colorblind, na.rm=TRUE), "\n")
cat("Male (y_chrom=1) colorblind rate:",
    mean(users$colorblind[users$y_chromosome == 1], na.rm=TRUE), "\n")
cat("Female (y_chrom=0) colorblind rate:",
    mean(users$colorblind[users$y_chromosome == 0], na.rm=TRUE), "\n")

cat("\n=== Count of answers by rank (top 10 most answered) ===\n")
rank_counts <- as.data.frame(table(answers$rank))
names(rank_counts) <- c("rank", "n_answers")
rank_counts$rank <- as.integer(as.character(rank_counts$rank))
rank_counts <- rank_counts[order(-rank_counts$n_answers), ]
print(head(rank_counts, 10))

cat("\n=== Merge rank counts with color names ===\n")
top_answered <- merge(rank_counts, color_ranks, by = "rank")
top_answered <- top_answered[order(-top_answered$n_answers), ]
print(head(top_answered, 20))
