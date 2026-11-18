# Checks for Day 16. Run from the repository root after acquire_day16() has filled the cache.
source("posts/2026-11-16-30daymap-16-collaborative-map/render-map.R")
cfg <- day16_config()

# Climatic years run April to March and take the year they start in.
stopifnot(identical(day16_climate_year(c("1990-03-31", "1990-04-01", "1991-03-31")), c(1989L, 1990L, 1990L)))

# Low flow: a dry week that straddles April 1 belongs to the climatic year its last day falls in, a missing day breaks
# only the windows that contain it, and estimated days are counted inside the lowest window.
local({
  days <- seq(as.Date("1990-03-20"), as.Date("1991-04-10"), by = "day")
  daily <- data.frame(site = "A", date = as.character(days), cfs = 100, estimated = FALSE)
  daily$cfs[days >= as.Date("1990-03-27") & days <= as.Date("1990-04-02")] <- 10
  daily$estimated[days == as.Date("1990-03-29")] <- TRUE
  daily <- daily[days != as.Date("1990-06-15"), ]
  # A second gage with under a week of values has no complete window and no rows.
  daily <- rbind(daily, data.frame(site = "B", date = as.character(days[1:5]), cfs = 1, estimated = FALSE))
  low <- day16_low_flow(daily)
  stopifnot(
    identical(low$site, c("A", "A", "A")), identical(low$climate_year, c(1989L, 1990L, 1991L)),
    identical(low$n_days, c(12L, 364L, 10L)),
    identical(low$min7_cfs, c(round(250 / 7, 1), 10, 100)),
    identical(low$min7_end, c("1990-03-31", "1990-04-02", "1991-04-01")),
    identical(low$n_estimated, c(1L, 1L, 0L))
  )
  dup <- tryCatch(day16_low_flow(daily[c(1, 1:20), ]), error = identity)
  stopifnot(inherits(dup, "error"), grepl("Duplicate", conditionMessage(dup)))
})

# Half footprints: the two halves of a square share no area and leave the configured gap between them.
local({
  sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0)))), crs = cfg$crs)
  e <- day16_half(sq, "east", 0.1)
  w <- day16_half(sq, "west", 0.1)
  stopifnot(abs(as.numeric(sf::st_area(e)) - 45) < 1e-9, abs(as.numeric(sf::st_area(w)) - 45) < 1e-9,
            sf::st_bbox(w)[["xmax"]] == 4.5, sf::st_bbox(e)[["xmin"]] == 5.5)
})

# The committed reductions and cache, end to end.
x <- prepare_day16(cfg)
stopifnot(
  nrow(x$facilities) == 1724L, x$grams_rows == 7615L,
  nrow(x$gages) == 12L, !any(x$gages$site %in% cfg$regulated), nrow(x$peaks) == 428L,
  nrow(x$low_gages) == 10L, nrow(x$low) == 361L, all(x$low$n_days >= cfg$low_min_days),
  all(table(x$low$site) >= cfg$min_peak_years), all(table(x$peaks$site) >= cfg$min_peak_years),
  length(unique(x$conductivity$group)) == 19L, nrow(x$conductivity) == 550L, x$wq_bad_units == 26L,
  all(x$conductivity$n_visits >= cfg$wq_min_visits),
  nrow(x$nas) == 4032L, nrow(x$nas_years) == 1160L, !anyDuplicated(x$nas$key),
  all(x$nas$accuracy %in% cfg$nas_accuracy), !any(x$nas$status %in% cfg$nas_drop_status),
  setequal(x$nas_years$group, names(cfg$nas_groups)), all(x$nas_years$first_year <= x$nas_years$year),
  nrow(x$places) == 11L
)
# Ranks: 1 is the highest peak and the driest year at each gage.
local({
  top <- x$peaks[x$peaks$rank == 1, ]
  stopifnot(all(top$peak_cfs == ave(x$peaks$peak_cfs, x$peaks$site, FUN = max)[x$peaks$rank == 1]))
  dry <- x$low[x$low$rank == 1, ]
  stopifnot(all(dry$min7_cfs == ave(x$low$min7_cfs, x$low$site, FUN = min)[x$low$rank == 1]))
})

# Slabs and stems: one TRI slab per hex-year with discharges; stems only under columns that start after 1987, as tall
# as the years before their first slab.
s <- day16_slabs(x)
stopifnot(nrow(s$tri) == 2928L, nrow(s$usgs) == nrow(s$`usgs-all`), nrow(s$low) == nrow(s$`low-all`),
          nrow(s$nas) == nrow(x$nas_years))
stems <- s[grep("-stem$", names(s))]
stopifnot(identical(vapply(stems, nrow, integer(1)), c(`tri-stem` = 56L, `usgs-stem` = 1L, `low-stem` = 1L,
                                                      `wq-stem` = 16L, `nas-stem` = 242L)))
# No two footprints of one layer and year share area (a shared top face flickers), nor do the split floods and
# low-water copies in "All". Stems stand from the ground, so they are compared across years.
overlaps <- function(g) sum(suppressMessages(sf::st_relate(g, g, pattern = "2********", sparse = FALSE))) - length(g)
for (k in c("tri", "usgs", "low", "wq", "nas", "usgs-all", "low-all")) {
  for (y in unique(s[[k]]$year)) stopifnot(overlaps(sf::st_geometry(s[[k]][s[[k]]$year == y, ])) == 0L)
}
both <- rbind(s$`usgs-all`[c("year", "b")], s$`low-all`[c("year", "b")])
for (y in unique(both$year)) stopifnot(overlaps(sf::st_geometry(both[both$year == y, ])) == 0L)
for (k in names(stems)) stopifnot(overlaps(sf::st_geometry(stems[[k]])) == 0L)
stopifnot(overlaps(c(sf::st_geometry(s$`usgs-stem-all`), sf::st_geometry(s$`low-stem-all`))) == 0L)
# Across all five "All" stem layers, no two stems are the same cylinder footprint.
local({
  g <- do.call(c, lapply(paste0(c("tri", "usgs", "low", "wq", "nas"), "-stem-all"), function(k) {
    sf::st_geometry(if (is.null(s[[k]])) s[[sub("-all$", "", k)]] else s[[k]])
  }))
  stopifnot(sum(lengths(suppressMessages(sf::st_equals(g)))) == length(g))
})
for (k in names(stems)) stopifnot(all(stems[[k]]$year > min(cfg$years)), all(stems[[k]]$b == stems[[k]]$year - min(cfg$years)))
local({
  hy <- x$hex_years[!is.na(x$hex_years$water_lbs) & x$hex_years$water_lbs > 0, ]
  first <- as.vector(tapply(hy$year, hy$hex_id, min))
  stopifnot(identical(sort(first[first > min(cfg$years)]), sort(stems$`tri-stem`$year)))
})

# The widget: every slab and stem layer is on the slider, each layer exists, and each switch entry carries its stems.
w <- build_day16_widget(x)
ledgers <- c("tri", "usgs", "low", "wq", "nas")
slabs <- c(ledgers, paste0(ledgers, "-all"))
stem_ids <- c(paste0(ledgers, "-stem"), paste0(ledgers, "-stem-all"))
stopifnot(setequal(unlist(w$x$slider_control$layers), c(slabs, stem_ids)),
          setequal(vapply(w$x$layers, function(l) l$id, character(1)), c("river", slabs, stem_ids, "places")))
stopifnot(isTRUE(w$x$fullscreen_control$enabled))
entries <- setNames(lapply(w$x$layers_control$layers_config, function(e) e$ids),
                    vapply(w$x$layers_control$layers_config, function(e) e$label, character(1)))
stopifnot(identical(entries$Industry, c("tri", "tri-stem")), identical(entries$Invasives, c("nas", "nas-stem")),
          setequal(entries$`All five`, c(paste0(ledgers, "-all"), paste0(ledgers, "-stem-all"))),
          setequal(unlist(entries), c(slabs, stem_ids)), !anyDuplicated(unlist(entries)))

# The static fallback image is a 2000 x 1125 PNG.
local({
  con <- file(file.path(day16_root, "artifacts/day16-river-ledger.png"), "rb")
  on.exit(close(con))
  stopifnot(identical(readBin(con, "raw", 8), as.raw(c(137, 80, 78, 71, 13, 10, 26, 10))))
  seek(con, 16)
  stopifnot(identical(readBin(con, "integer", 2, size = 4, endian = "big"), c(2000L, 1125L)))
})
cat("Day 16 checks passed\n")
