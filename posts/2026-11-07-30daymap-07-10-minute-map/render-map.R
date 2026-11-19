#!/usr/bin/env Rscript
# Offline map: all source requests and reductions are prepared by acquire-data.R.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day07_root <- "posts/2026-11-07-30daymap-07-10-minute-map"
day07_cache <- "data/30daymap/2026/day07"
day07_config <- function() list(
  crs = 26916L, origin = c(lon = -84.5125001, lat = 39.1014843),
  bounds = c(-84.65, 38.99, -84.37, 39.21),
  modes = c("pedestrian", "bicycle", "auto"),
  colors = c(pedestrian = "#EBC06D", bicycle = "#73C0C6", auto = "#E78D73"),
  background = "#15232B", ink = "#EAE5D8", muted = "#A1ADB0", roads = "#45565E", water = "#253E4A"
)

day07_requests <- function() {
  cfg <- day07_config()
  options <- list(pedestrian = list(walking_speed = 5.1),
                  bicycle = list(bicycle_type = "hybrid", cycling_speed = 18, use_hills = 0.25),
                  auto = list(speed_types = character()))
  stats::setNames(lapply(cfg$modes, function(mode) list(
    locations = list(as.list(cfg$origin[c("lat", "lon")])), costing = mode,
    costing_options = stats::setNames(list(options[[mode]]), mode),
    contours = list(list(time = 5), list(time = 10)), polygons = TRUE,
    denoise = 0, generalize = 10, show_locations = TRUE, reverse = FALSE
  )), cfg$modes)
}

day07_radius <- function(geometry, origin) {
  # Maximum projected straight-line distance to the contour, not route length.
  xy <- sf::st_coordinates(geometry)[, c("X", "Y"), drop = FALSE]
  max(sqrt((xy[, 1] - origin[1])^2 + (xy[, 2] - origin[2])^2)) / 1000
}

read_day07 <- function() {
  cfg <- day07_config()
  read <- function(name) sf::st_read(file.path(day07_root, name), quiet = TRUE) |> sf::st_transform(cfg$crs)
  contours <- read("isochrones.geojson")
  if (nrow(contours) != 6 || !setequal(contours$mode, cfg$modes) ||
      anyDuplicated(paste(contours$mode, contours$minutes)) ||
      !setequal(contours$minutes, c(5, 10)) || any(sf::st_is_empty(contours)) ||
      !all(sf::st_is_valid(contours)) || !all(sf::st_geometry_type(contours) %in% c("POLYGON", "MULTIPOLYGON")))
    stop("Invalid isochrone reduction")
  origin <- sf::st_as_sf(data.frame(lon = cfg$origin[1], lat = cfg$origin[2]), coords = c("lon", "lat"), crs = 4326) |>
    sf::st_transform(cfg$crs)
  list(contours = contours, origin = origin, roads = read("roads.geojson"), water = read("water.geojson"))
}

verify_day07 <- function() {
  snapshot <- jsonlite::read_json(file.path(day07_root, "source-snapshot.json"), simplifyVector = TRUE)
  for (i in seq_len(nrow(snapshot$render_inputs))) {
    x <- snapshot$render_inputs[i, ]
    if (!file.exists(x$path) || digest::digest(file = x$path, algo = "sha256") != x$sha256)
      stop("Missing or changed reduction: ", x$path)
  }
}

draw_day07 <- function(data, cfg = day07_config()) {
  origin <- sf::st_coordinates(data$origin)[1, ]
  # Square viewport derived once from every mode, reused unchanged in all panels.
  box <- sf::st_bbox(data$contours)
  side <- max(box[3] - box[1], box[4] - box[2]) * 1.17
  center <- c(mean(box[c(1, 3)]), mean(box[c(2, 4)]))
  limits <- list(x = center[1] + c(-0.5, 0.5) * side, y = center[2] + c(-0.5, 0.5) * side)
  graphics::par(bg = cfg$background, family = "sans", mar = rep(0, 4), xpd = FALSE)
  names <- c("WALK", "BIKE", "DRIVE")
  assumptions <- c("5.1 km/h walking baseline", "Hybrid bicycle / 18 km/h baseline", "Static road speeds / parking excluded")
  labels <- data.frame(name = c("CINCINNATI", "COVINGTON", "NEWPORT", "NORWOOD"),
                        lon = c(-84.518, -84.520, -84.487, -84.459), lat = c(39.121, 39.073, 39.081, 39.161))
  places <- sf::st_as_sf(labels, coords = c("lon", "lat"), crs = 4326) |> sf::st_transform(cfg$crs)
  xy <- sf::st_coordinates(places)
  for (i in seq_along(cfg$modes)) {
    mode <- cfg$modes[i]; color <- cfg$colors[[mode]]
    x0 <- 0.035 + (i - 1) * 0.326
    graphics::par(fig = c(x0, x0 + 0.302, 0.282, 0.827), mar = rep(0, 4), new = i > 1)
    graphics::plot.new()
    graphics::plot.window(limits$x, limits$y, asp = 1, xaxs = "i", yaxs = "i")
    graphics::rect(limits$x[1], limits$y[1], limits$x[2], limits$y[2], col = "#1B2D36", border = NA)
    plot(sf::st_geometry(data$roads), add = TRUE, col = cfg$roads, lwd = 0.45)
    outer <- data$contours[data$contours$mode == mode & data$contours$minutes == 10, ]
    inner <- data$contours[data$contours$mode == mode & data$contours$minutes == 5, ]
    plot(sf::st_geometry(outer), add = TRUE, col = grDevices::adjustcolor(color, 0.32), border = color, lwd = 1.3)
    plot(sf::st_geometry(inner), add = TRUE, col = grDevices::adjustcolor(color, 0.7), border = color, lwd = 0.65)
    # River fill restores geographic context over interpolated contours; it does not alter the routing result.
    plot(sf::st_geometry(data$water), add = TRUE, col = cfg$water, border = NA)
    for (j in seq_len(nrow(places))) graphics::text(xy[j, 1], xy[j, 2], labels$name[j],
                                                   cex = 0.63, col = cfg$muted, font = 2)
    graphics::points(origin[1], origin[2], pch = 4, cex = 1.0, lwd = 1.5, col = cfg$ink)
    sx <- limits$x[1] + side * 0.06; sy <- limits$y[1] + side * 0.06
    graphics::segments(sx, sy, sx + 5000, sy, col = cfg$ink, lwd = 1.2)
    graphics::segments(c(sx, sx + 5000), sy - 100, c(sx, sx + 5000), sy + 100, col = cfg$ink)
    graphics::text(sx + 2500, sy + 350, "5 km", col = cfg$ink, cex = 0.66)
    graphics::box(col = "#50606A", lwd = 0.7)
  }
  graphics::par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE, xpd = NA)
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  graphics::text(0.035, 0.968, "07 / 10 MINUTE MAP     \u2022     CINCINNATI", adj = 0, col = cfg$muted, cex = 0.9)
  graphics::text(0.035, 0.919, "Ten minutes from Fountain Square", adj = 0, col = cfg$ink, cex = 2.1, font = 2)
  graphics::text(0.035, 0.875, "1 starting point / 3 ways to move / the same map scale", adj = 0, col = cfg$ink, cex = 1)
  for (i in seq_along(cfg$modes)) {
    x0 <- 0.035 + (i - 1) * 0.326; mode <- cfg$modes[i]; color <- cfg$colors[[mode]]
    p <- data$contours[data$contours$mode == mode & data$contours$minutes == 10, ]
    radius <- day07_radius(sf::st_geometry(p), origin)
    graphics::text(x0, 0.837, names[i], adj = 0, col = color, cex = 0.95, font = 2)
    graphics::text(x0, 0.252, sprintf("%.1f km", radius), adj = 0, col = color, cex = 2, font = 2)
    graphics::text(x0, 0.217, "FARTHEST STRAIGHT-LINE EXTENT", adj = 0, col = cfg$muted, cex = 0.65)
    graphics::text(x0, 0.181, assumptions[i], adj = 0, col = cfg$ink, cex = 0.8)
    graphics::rect(x0, 0.125, x0 + 0.015, 0.143, col = grDevices::adjustcolor(color, 0.32), border = color)
    graphics::text(x0 + 0.023, 0.134, "10 minutes", adj = 0, col = cfg$ink, cex = 0.76)
    graphics::rect(x0 + 0.12, 0.125, x0 + 0.135, 0.143, col = grDevices::adjustcolor(color, 0.7), border = color)
    graphics::text(x0 + 0.143, 0.134, "5 minutes", adj = 0, col = cfg$ink, cex = 0.76)
  }
  graphics::text(0.035, 0.083, "\u00d7 Fountain Square / Outward network travel / Contours interpolate between streets; shaded land is not all accessible.",
                 adj = 0, col = cfg$muted, cex = 0.78)
  graphics::text(0.035, 0.041, "Valhalla / FOSSGIS \u00b7 \u00a9 OpenStreetMap contributors (ODbL) / Census TIGERweb context / NAD83 UTM 16N",
                 adj = 0, col = cfg$muted, cex = 0.72)
  graphics::text(0.035, 0.016, "Retrieved 11 Nov 2026 / Static speeds, no live traffic or parking search / Sean Thimons / #30DayMapChallenge",
                 adj = 0, col = cfg$muted, cex = 0.72)
}

render_day07 <- function() {
  verify_day07()
  data <- read_day07()
  out <- file.path(day07_root, "artifacts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  save <- function(open) {
    open(); on.exit(grDevices::dev.off()); draw_day07(data)
  }
  save(function() grDevices::png(file.path(out, "day07-ten-minutes.png"), width = 5400, height = 3000,
                                  res = 300, type = "cairo", bg = day07_config()$background))
  save(function() grDevices::cairo_pdf(file.path(out, "day07-ten-minutes.pdf"), width = 18, height = 10,
                                        bg = day07_config()$background))
  versions <- list(R = R.version.string, sf = as.character(utils::packageVersion("sf")),
                   external = sf::sf_extSoftVersion(), config = day07_config())
  writeLines(trimws(capture.output(dput(versions)), which = "right"), file.path(out, "provenance.R"))
  invisible(data)
}
if (sys.nframe() == 0L) render_day07()
