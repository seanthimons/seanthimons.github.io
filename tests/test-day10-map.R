# Checks for Day 10. Run from the repository root after acquire_day10() and build_day10().
source("posts/2026-11-10-30daymap-10-prompting-only/render-map.R")
cfg <- day10_config()

# Terrarium encoding round-trips, including below sea level, and stays in 0..1 for png.
local({
  elev <- matrix(c(-222.9, 0, 183.2, 1234.56), 2)
  rgb <- day10_terrarium(elev)
  stopifnot(all(rgb >= 0 & rgb <= 1), max(abs(day10_unterrarium(rgb) - elev)) < 1 / 256)
})

# Tile math: the Fitzgerald is in z10 tile 269/360, and that tile's bounds contain it.
local({
  stopifnot(identical(unname(day10_tile_xy(-85.108, 46.999, 10)), c(269, 360)))
  b <- day10_tile_bounds(269, 360, 10)
  p <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_point(c(-85.108, 46.999)), crs = 4326), 3857))
  stopifnot(p[1] > b[["xmin"]], p[1] < b[["xmax"]], p[2] > b[["ymin"]], p[2] < b[["ymax"]])
})

# Committed tables match the snapshot; a changed table is rejected.
stopifnot(check_day10_snapshot())
local({
  f <- file.path(day10_root, "enc-wrecks.csv"); keep <- readLines(f)
  on.exit(writeLines(keep, f))
  writeLines(c(keep, "0,0,changed"), f)
  stopifnot(inherits(tryCatch(check_day10_snapshot(), error = identity), "error"))
})

# Wrecks: every exclusion matched a row; the Fitzgerald is kept, deep, and within 500 m of the NOAA chart wreck.
local({
  w <- utils::read.csv(file.path(day10_root, "wrecks.csv"))
  enc <- utils::read.csv(file.path(day10_root, "enc-wrecks.csv"))
  stopifnot(!anyNA(w[c("lon", "lat")]), all(names(cfg$exclude) %in% w$qid), sum(is.na(w$excluded)) == 51)
  fitz <- w[w$qid == cfg$fitzgerald, ]
  stopifnot(nrow(fitz) == 1, is.na(fitz$excluded), fitz$floor_m < -140)
  d <- sf::st_distance(sf::st_sfc(sf::st_point(c(fitz$lon, fitz$lat)), crs = 4326),
                       sf::st_as_sf(enc, coords = c("lon", "lat"), crs = 4326))
  stopifnot(min(as.numeric(d)) < 500)
})

# Tiles: every zoom is present and a tile over open water decodes below the lake datum.
local({
  stopifnot(all(dir.exists(file.path(day10_root, "terrain", cfg$zooms))))
  t <- png::readPNG(file.path(day10_root, "terrain/9/134/180.png"))
  stopifnot(min(day10_unterrarium(t)) < cfg$datum_m - 100)
})

# The widget carries the hook that adds terrain, with the tile template and encoding.
local({
  m <- render_day10()
  js <- paste(unlist(m$jsHooks), collapse = "\n")
  stopifnot(grepl("terrain/{z}/{x}/{y}.png", js, fixed = TRUE), grepl("encoding: 'terrarium'", js, fixed = TRUE),
            grepl("exaggeration: 30", js, fixed = TRUE))
})
cat("Day 10 checks passed\n")
