options(repos = c(CRAN = "https://cloud.r-project.org"))
library(tidytuesdayR)
library(dplyr)
library(tidyr)
library(paletteer)
library(scales)

raw <- tidytuesdayR::tt_load("2025-08-26")
billboard <- raw$billboard

instrument_map <- c(
  "guitar_based"         = "Guitar",
  "piano_keyboard_based" = "Piano / Keyboard",
  "bass_based"           = "Bass",
  "orchestral_strings"   = "Orchestral Strings",
  "horns_winds"          = "Horns & Winds",
  "saxophone"            = "Saxophone",
  "trumpet"              = "Trumpet",
  "violin"               = "Violin",
  "handclaps_snaps"      = "Handclaps / Snaps",
  "falsetto_vocal"       = "Falsetto Vocal",
  "bongos"               = "Bongos",
  "harmonica"            = "Harmonica",
  "banjo"                = "Banjo",
  "accordion"            = "Accordion",
  "flute_piccolo"        = "Flute / Piccolo",
  "clarinet"             = "Clarinet",
  "sitar"                = "Sitar",
  "ukulele"              = "Ukulele",
  "mandolin"             = "Mandolin",
  "human_whistling"      = "Human Whistling",
  "cowbell"              = "Cowbell",
  "kazoo"                = "Kazoo",
  "vocally_based"        = "A cappella / Voice-led"
)

inst_cols <- names(instrument_map)

# Check all columns exist
missing <- setdiff(inst_cols, names(billboard))
cat(sprintf("Missing columns: %s\n", if (length(missing) == 0) "NONE" else paste(missing, collapse=", ")))

# Build decade-by-instrument proportions
inst_decade <- billboard %>%
  mutate(
    year   = as.integer(format(date, "%Y")),
    decade = paste0(floor(year / 10) * 10, "s")
  ) %>%
  group_by(decade) %>%
  summarise(
    across(all_of(inst_cols), ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  pivot_longer(-decade, names_to = "instrument_col", values_to = "proportion") %>%
  mutate(
    instrument = instrument_map[instrument_col],
    pct        = proportion * 100
  )

cat(sprintf("inst_decade: %d rows, %d cols\n", nrow(inst_decade), ncol(inst_decade)))
stopifnot("Plot data has 0 rows" = nrow(inst_decade) > 0)

pct_summary <- inst_decade %>%
  summarise(min_pct = min(pct), max_pct = max(pct), mean_pct = mean(pct))
cat(sprintf("Pct range: %.1f%% to %.1f%% (mean %.1f%%)\n",
            pct_summary$min_pct, pct_summary$max_pct, pct_summary$mean_pct))
stopifnot("All pct values identical" = length(unique(inst_decade$pct)) > 1)

cat("\nSample rows:\n")
print(head(inst_decade, 10))

# Verify sonic features pipeline
sonic_year <- billboard %>%
  mutate(year = as.integer(format(date, "%Y"))) %>%
  group_by(year) %>%
  summarise(
    Energy       = mean(energy, na.rm = TRUE),
    Danceability = mean(danceability, na.rm = TRUE),
    Happiness    = mean(happiness, na.rm = TRUE),
    Acousticness = mean(acousticness, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(-year, names_to = "feature", values_to = "value")

cat(sprintf("\nsonic_year: %d rows\n", nrow(sonic_year)))
stopifnot("sonic_year empty" = nrow(sonic_year) > 0)

# Verify MexBrewer::Atentado palette
feature_colors <- paletteer::paletteer_d("MexBrewer::Atentado", n = 10)[c(1, 3, 6, 9)]
cat(sprintf("\nfeature_colors: %d colors: %s\n", length(feature_colors), paste(feature_colors, collapse=", ")))

# Verify scico::bamako palette
bamako <- paletteer::paletteer_c("scico::bamako", n = 10)
cat(sprintf("bamako: %d colors\n", length(bamako)))

cat("\nAll checks PASSED!\n")
