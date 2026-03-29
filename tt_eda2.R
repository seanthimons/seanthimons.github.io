options(repos = c(CRAN = "https://cloud.r-project.org"))
library(tidytuesdayR)
library(dplyr)

raw <- tidytuesdayR::tt_load("2025-08-26")
billboard <- raw$billboard

# Date range
cat("=== Date range ===\n")
cat("Min date:", format(min(billboard$date, na.rm=TRUE)), "\n")
cat("Max date:", format(max(billboard$date, na.rm=TRUE)), "\n")

# Add year/decade
billboard <- billboard %>%
  mutate(
    year = as.integer(format(date, "%Y")),
    decade = paste0(floor(year / 10) * 10, "s")
  )

cat("\n=== Year distribution ===\n")
print(table(billboard$decade))

# Musical features summary
cat("\n=== Musical features summary ===\n")
features <- c("bpm", "energy", "danceability", "happiness", "loudness_d_b", "acousticness")
for (f in features) {
  vals <- billboard[[f]]
  cat(sprintf("%s: min=%.1f, mean=%.1f, max=%.1f, NA=%d\n",
    f, min(vals,na.rm=T), mean(vals,na.rm=T), max(vals,na.rm=T), sum(is.na(vals))))
}

# Genre distribution
cat("\n=== CDR Genre ===\n")
print(sort(table(billboard$cdr_genre), decreasing=TRUE))

cat("\n=== Discogs Genre ===\n")
print(sort(table(billboard$discogs_genre), decreasing=TRUE))

# Artist demographics
cat("\n=== Artist demographics ===\n")
cat("artist_male (1=male, 0=female):\n")
print(table(billboard$artist_male, useNA="ifany"))
cat("artist_white:\n")
print(table(billboard$artist_white, useNA="ifany"))
cat("artist_black:\n")
print(table(billboard$artist_black, useNA="ifany"))

# Weeks at number one
cat("\n=== Weeks at #1 distribution ===\n")
cat("Mean:", mean(billboard$weeks_at_number_one, na.rm=T), "\n")
cat("Median:", median(billboard$weeks_at_number_one, na.rm=T), "\n")
cat("Max:", max(billboard$weeks_at_number_one, na.rm=T), "\n")
cat("\nTop 10 longest-running #1s:\n")
billboard %>%
  arrange(desc(weeks_at_number_one)) %>%
  select(song, artist, date, weeks_at_number_one) %>%
  head(10) %>%
  print()

# Instrument presence across decades
cat("\n=== Instrument columns ===\n")
instrument_cols <- c("vocally_based","bass_based","guitar_based","piano_keyboard_based",
  "orchestral_strings","horns_winds","accordion","banjo","bongos","clarinet",
  "cowbell","falsetto_vocal","flute_piccolo","handclaps_snaps","harmonica",
  "human_whistling","kazoo","mandolin","saxophone","sitar","trumpet","ukulele","violin")
available_cols <- intersect(instrument_cols, names(billboard))
cat("Available instrument cols:", paste(available_cols, collapse=", "), "\n")

inst_by_decade <- billboard %>%
  group_by(decade) %>%
  summarise(across(all_of(available_cols), ~mean(.x, na.rm=TRUE))) %>%
  arrange(decade)

cat("\nInstrument presence by decade (proportion):\n")
print(inst_by_decade)

# Musical feature trends by decade
cat("\n=== Musical features by decade ===\n")
feat_by_decade <- billboard %>%
  group_by(decade) %>%
  summarise(
    n = n(),
    mean_bpm = mean(bpm, na.rm=TRUE),
    mean_energy = mean(energy, na.rm=TRUE),
    mean_dance = mean(danceability, na.rm=TRUE),
    mean_happy = mean(happiness, na.rm=TRUE),
    mean_loud = mean(loudness_d_b, na.rm=TRUE),
    mean_acoustic = mean(acousticness, na.rm=TRUE)
  )
print(feat_by_decade)

# lyrical topics
cat("\n=== Top lyrical topics ===\n")
print(sort(table(billboard$lyrical_topic), decreasing=TRUE)[1:20])

# Overall rating by genre
cat("\n=== Overall rating by genre ===\n")
billboard %>%
  group_by(cdr_genre) %>%
  summarise(
    n = n(),
    mean_rating = mean(overall_rating, na.rm=TRUE),
    mean_divisiveness = mean(divisiveness, na.rm=TRUE)
  ) %>%
  arrange(desc(n)) %>%
  print()

# Artist origin
cat("\n=== Top artist origins ===\n")
print(sort(table(billboard$artist_place_of_origin), decreasing=TRUE)[1:15])
