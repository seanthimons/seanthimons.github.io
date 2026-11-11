# Run from the repository root with sh scripts/map-r.sh.
library(magrittr)
source("posts/2026-11-07-30daymap-07-10-minute-map/render-map.R")
cfg <- day07_config()
verify_day07()
x <- read_day07()
req <- day07_requests()
stopifnot(identical(names(req), cfg$modes), length(req$auto$costing_options$auto$speed_types) == 0,
          req$pedestrian$costing_options$pedestrian$walking_speed == 5.1,
          req$bicycle$costing_options$bicycle$cycling_speed == 18,
          all(vapply(req, function(r) identical(r$locations, req[[1]]$locations), logical(1))),
          all(vapply(req, function(r) !r$reverse && r$polygons && r$show_locations, logical(1))))
# A common origin and 5/10-minute outward polygons in each mode; larger budgets must expand.
origin <- sf::st_geometry(x$origin)
for (mode in cfg$modes) {
  a <- x$contours[x$contours$mode == mode & x$contours$minutes == 5, ]
  b <- x$contours[x$contours$mode == mode & x$contours$minutes == 10, ]
  stopifnot(nrow(a) == 1, nrow(b) == 1, sf::st_area(b) > sf::st_area(a),
            lengths(sf::st_intersects(origin, b)) == 1)
  # Generalized grid contours may differ by a few edge pixels; a material inversion is a failure.
  outside <- suppressWarnings(sf::st_difference(sf::st_geometry(a), sf::st_geometry(b)))
  stopifnot(sum(as.numeric(sf::st_area(outside))) < as.numeric(sf::st_area(a)) * 0.01)
}
# Straight-line helper: a 3-4-5 triangle must yield 5 km, independent of the plotted scale.
triangle <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(3000, 0), c(3000, 4000), c(0, 0)))), crs = cfg$crs)
stopifnot(abs(day07_radius(triangle, c(0, 0)) - 5) < 1e-12)
snaps <- utils::read.csv(file.path(day07_root, "origin-snaps.csv"))
stopifnot(setequal(snaps$mode, cfg$modes), all(is.finite(snaps$distance_m)), max(snaps$distance_m) < 100)
# Context geometry is nonempty, valid and in the same projected CRS.
for (layer in c("roads", "water")) {
  stopifnot(nrow(x[[layer]]) > 0, all(sf::st_is_valid(x[[layer]])),
            all(sf::st_crs(x[[layer]]) == sf::st_crs(x$contours)))
}
summary <- utils::read.csv(file.path(day07_root, "summary.csv"))
for (i in seq_len(nrow(summary))) {
  polygon <- x$contours[x$contours$mode == summary$mode[i] & x$contours$minutes == 10, ]
  radius <- day07_radius(sf::st_geometry(polygon), sf::st_coordinates(x$origin)[1, ])
  stopifnot(abs(radius - summary$max_straight_line_km[i]) < 0.001)
}
stopifnot(summary$max_straight_line_km[summary$mode == "pedestrian"] < summary$max_straight_line_km[summary$mode == "bicycle"],
          summary$max_straight_line_km[summary$mode == "bicycle"] < summary$max_straight_line_km[summary$mode == "auto"])
cat("Day 07 request, geometry and reduction checks passed\n")
