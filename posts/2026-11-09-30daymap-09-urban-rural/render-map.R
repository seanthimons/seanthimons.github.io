#!/usr/bin/env Rscript
# Offline rendering; acquisition and routing live in acquire-data.R.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day09_root <- "posts/2026-11-09-30daymap-09-urban-rural"
day09_cache <- "data/30daymap/2026/day09"
day09_config <- function() list(
  crs = 26916L, modes = c("pedestrian", "auto"), minutes = c(5, 10),
  drive_buffer_m = 25000, walk_buffer_m = 2000, max_snap_m = 500,
  background = "#14232B", ink = "#EAE5D8", muted = "#A8B6B9", rural = "#20323C", urban = "#394B54",
  colors = c(pedestrian = "#EBC06D", auto = "#75C3CB"), historical = "#DE8D93"
)

day09_store_eligible <- function(type, name) {
  type %in% c("Supermarket", "Super Store") &
    !grepl("costco|sam.?s.?club", name, ignore.case = TRUE)
}

day09_request <- function(lon, lat, mode) {
  if (!mode %in% day09_config()$modes || !is.finite(lon) || !is.finite(lat)) stop("Invalid routing input")
  options <- if (mode == "pedestrian") list(walking_speed = 5.1) else
    list(speed_types = character(), top_speed = 140, ignore_closures = TRUE)
  list(locations = list(list(lat = lat, lon = lon)), costing = mode,
       costing_options = stats::setNames(list(options), mode),
       contours = list(list(time = 5), list(time = 10)), polygons = TRUE,
       denoise = 0, generalize = 10, show_locations = TRUE, reverse = TRUE)
}

verify_day09 <- function() {
  x <- jsonlite::read_json(file.path(day09_root, "source-snapshot.json"), simplifyVector = TRUE)
  for (i in seq_len(nrow(x$render_inputs))) {
    f <- x$render_inputs[i, ]
    if (!file.exists(f$path) || digest::digest(file = f$path, algo = "sha256") != f$sha256)
      stop("Missing or changed input: ", f$path)
  }
  x
}

read_day09 <- function() {
  p <- file.path(day09_root, "grocery-access.gpkg")
  read <- function(layer) sf::st_read(p, layer = layer, quiet = TRUE)
  data <- list(counties = read("counties"), stores = read("stores"), access = read("access"),
               urban = read("urban"), tracts = read("fara2019"))
  if (nrow(data$counties) != 2 || !setequal(data$counties$GEOID, c("39061", "39025")) ||
      nrow(data$access) != 4 || anyDuplicated(paste(data$access$mode, data$access$minutes)) ||
      !setequal(data$access$mode, day09_config()$modes) || !setequal(data$access$minutes, c(5, 10)) ||
      anyDuplicated(data$stores$Record_ID) || !all(day09_store_eligible(data$stores$Store_Type, data$stores$Store_Name)) ||
      any(sf::st_is_empty(data$access)) || !all(sf::st_is_valid(data$access))) stop("Invalid grocery-access reduction")
  selections <- utils::read.csv(file.path(day09_root, "callout-selections.csv"),
                                colClasses = c(GEOID10 = "character"))
  indices <- match(selections$GEOID10, data$tracts$GEOID10)
  if (anyNA(indices) || anyDuplicated(selections$GEOID10) || anyDuplicated(selections$number) ||
      !all(data$tracts$LILATracts_Vehicle[indices] == 1)) stop("Invalid historical tract callouts")
  # Anchors are interior points of the selected historical tracts, not neighbourhood centroids.
  data$callouts <- sf::st_sf(selections, geometry = sf::st_point_on_surface(sf::st_geometry(data$tracts[indices, ])))
  data$region <- sf::st_union(sf::st_geometry(data$counties))
  data
}

render_day09 <- function() {
  library(magrittr)
  snapshot <- verify_day09(); data <- read_day09(); cfg <- day09_config()
  out <- file.path(day09_root, "artifacts"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  save <- function(open) { open(); on.exit(grDevices::dev.off()); draw_day09(data, snapshot) }
  save(function() grDevices::png(file.path(out, "day09-groceries-without-a-car.png"), width = 5400, height = 3600,
                                  res = 300, type = "cairo", bg = cfg$background))
  save(function() grDevices::cairo_pdf(file.path(out, "day09-groceries-without-a-car.pdf"), width = 18, height = 12, bg = cfg$background))
  writeLines(trimws(capture.output(dput(list(R = R.version.string, sf = as.character(utils::packageVersion("sf")),
                                            external = sf::sf_extSoftVersion(), config = cfg))), which = "right"),
             file.path(out, "provenance.R"))
  invisible(data)
}

draw_day09 <- function(data, snapshot, cfg = day09_config()) {
  bbox <- sf::st_bbox(data$region); pad <- 2500
  xlim <- c(bbox[1] - pad, bbox[3] + pad); ylim <- c(bbox[2] - pad, bbox[4] + pad)
  graphics::par(bg = cfg$background, family = "sans", mar = rep(0, 4), xpd = FALSE)
  flagged <- data$tracts[data$tracts$LILATracts_Vehicle == 1, ]
  stores <- data$stores[data$stores$inside_study, ]
  callout_xy <- sf::st_coordinates(data$callouts)
  # Approximate city-label anchors only; these points are not routing inputs or demographic estimates.
  labels <- data.frame(label = c("CINCINNATI", "MILFORD", "BATAVIA", "FELICITY", "HARRISON"),
                       lon = c(-84.513, -84.295, -84.177, -84.097, -84.816),
                       lat = c(39.101, 39.176, 39.077, 38.839, 39.261))
  anchors <- sf::st_as_sf(labels, coords = c("lon", "lat"), crs = 4326) %>% sf::st_transform(cfg$crs)
  xy <- sf::st_coordinates(anchors)
  for (i in seq_along(cfg$modes)) {
    mode <- cfg$modes[i]; color <- cfg$colors[[mode]]
    left <- if (i == 1) 0.035 else 0.52
    graphics::par(fig = c(left, left + 0.445, 0.33, 0.82), mar = rep(0, 4), new = i > 1)
    graphics::plot.new(); graphics::plot.window(xlim, ylim, asp = 1, xaxs = "i", yaxs = "i")
    plot(data$region, add = TRUE, col = cfg$rural, border = NA)
    plot(sf::st_geometry(data$urban), add = TRUE, col = cfg$urban, border = NA)
    plot(sf::st_geometry(flagged), add = TRUE, col = grDevices::adjustcolor(cfg$historical, 0.30), border = NA)
    for (minutes in c(10, 5)) {
      p <- data$access[data$access$mode == mode & data$access$minutes == minutes, ]
      plot(sf::st_geometry(p), add = TRUE, col = grDevices::adjustcolor(color, if (minutes == 5) 0.63 else 0.24),
           border = grDevices::adjustcolor(color, if (minutes == 5) 0.8 else 0.5), lwd = 0.5)
    }
    plot(sf::st_geometry(flagged), add = TRUE, col = NA, border = cfg$historical, lwd = 0.95)
    plot(sf::st_geometry(data$counties), add = TRUE, col = NA, border = "#8C9DA4", lwd = 0.65)
    graphics::points(sf::st_coordinates(stores), pch = 21, bg = cfg$ink, col = cfg$background, cex = 0.44, lwd = 0.4)
    for (j in seq_len(nrow(anchors))) {
      # A dark backing keeps labels legible where store catchments overlap.
      w <- graphics::strwidth(labels$label[j], cex = 0.57)
      h <- graphics::strheight(labels$label[j], cex = 0.57)
      lx <- xy[j, 1]; ly <- xy[j, 2] + 750
      graphics::rect(lx - w * 0.54, ly - h * 0.6, lx + w * 0.54, ly + h * 0.6,
                     col = grDevices::adjustcolor(cfg$background, 0.85), border = NA)
      graphics::text(lx, ly, labels$label[j], cex = 0.57, col = cfg$ink, font = 2)
    }
    for (j in seq_len(nrow(data$callouts))) {
      x <- callout_xy[j, 1]; y <- callout_xy[j, 2]
      lx <- x + data$callouts$dx_m[j]; ly <- y + data$callouts$dy_m[j]
      graphics::segments(x, y, lx, ly, col = cfg$historical, lwd = 1.15)
      graphics::points(x, y, pch = 16, col = cfg$historical, cex = 0.45)
      graphics::points(lx, ly, pch = 21, bg = cfg$background, col = cfg$historical, cex = 1.7, lwd = 1.25)
      graphics::text(lx, ly, data$callouts$number[j], col = cfg$ink, cex = 0.66, font = 2)
    }
    sx <- xlim[1] + 3500; sy <- ylim[1] + 3500
    graphics::segments(sx, sy, sx + 10000, sy, col = cfg$ink, lwd = 1.2)
    graphics::segments(c(sx, sx + 10000), sy - 180, c(sx, sx + 10000), sy + 180, col = cfg$ink)
    graphics::text(sx + 5000, sy + 700, "10 km", cex = 0.68, col = cfg$ink)
  }
  graphics::par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE, xpd = NA)
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  graphics::text(0.035, 0.969, "09 / URBAN-RURAL     \u2022     HAMILTON + CLERMONT COUNTIES, OHIO", adj = 0, col = cfg$muted, cex = 0.9)
  graphics::text(0.035, 0.922, "Groceries without a car", adj = 0, col = cfg$ink, cex = 2.15, font = 2)
  graphics::text(0.035, 0.882, sprintf("%s selected stores inside the study area / the same five- and ten-minute budgets", snapshot$counts$inside_study),
                 adj = 0, col = cfg$ink, cex = 0.97)
  for (i in seq_along(cfg$modes)) {
    left <- if (i == 1) 0.035 else 0.52; color <- cfg$colors[[cfg$modes[i]]]
    graphics::text(left, 0.837, if (i == 1) "WALK TO A STORE" else "DRIVE TO A STORE", adj = 0, col = color, cex = 0.98, font = 2)
    graphics::text(left, 0.305, if (i == 1) "5.1 km/h walking baseline" else "Static road speeds / parking time excluded",
                   adj = 0, col = cfg$ink, cex = 0.85)
    for (j in 1:2) {
      x <- left + (j - 1) * 0.135
      graphics::rect(x, 0.266, x + 0.015, 0.282, col = grDevices::adjustcolor(color, if (j == 1) 0.63 else 0.24), border = color)
      graphics::text(x + 0.023, 0.274, if (j == 1) "5 minutes" else "10 minutes", adj = 0, col = cfg$ink, cex = 0.77)
    }
  }
  graphics::rect(0.035, 0.226, 0.05, 0.242, col = grDevices::adjustcolor(cfg$historical, 0.30), border = cfg$historical)
  graphics::text(0.058, 0.234, sprintf("FOOD-DESERT FLAGS / USDA 2019: %s low-income, low-access tracts (vehicle measure)", snapshot$counts$historical_vehicle_lila),
                 adj = 0, col = cfg$historical, cex = 0.86, font = 2)
  graphics::text(0.035, 0.211, "Numbered examples locate selected tracts within these places; they do not designate the entire neighbourhood or township.",
                 adj = 0, col = cfg$muted, cex = 0.73)
  for (j in seq_len(nrow(data$callouts))) {
    left <- if (j <= 3) 0.035 else 0.52
    y <- 0.184 - (if (j <= 3) j - 1 else j - 4) * 0.023
    graphics::points(left + 0.006, y, pch = 21, bg = cfg$background, col = cfg$historical, cex = 1.3, lwd = 1)
    graphics::text(left + 0.006, y, data$callouts$number[j], col = cfg$ink, cex = 0.59, font = 2)
    graphics::text(left + 0.022, y, paste0(data$callouts$label[j], " / tract ", data$callouts$GEOID10[j]),
                   adj = 0, col = cfg$ink, cex = 0.78)
  }
  graphics::points(0.04, 0.087, pch = 21, bg = cfg$ink, col = cfg$background, cex = 0.65)
  graphics::text(0.058, 0.087, "SNAP-listed supermarket / superstore", adj = 0, col = cfg$ink, cex = 0.77)
  graphics::rect(0.43, 0.080, 0.445, 0.094, col = cfg$urban, border = NA)
  graphics::text(0.453, 0.087, "2020 urban footprint", adj = 0, col = cfg$ink, cex = 0.77)
  graphics::rect(0.68, 0.080, 0.695, 0.094, col = cfg$rural, border = "#60727A", lwd = 0.5)
  graphics::text(0.703, 0.087, "Rural remainder", adj = 0, col = cfg$ink, cex = 0.77)
  graphics::text(0.035, 0.062, "Catchments reach at least one included store. Nearby stores across county/state lines contribute; interiors are interpolated envelopes.",
                 adj = 0, col = cfg$muted, cex = 0.73)
  graphics::text(0.035, 0.044, "Historical tract flags are not a current food-desert designation. Smaller/specialty stores, transit, hours and affordability are outside this model.",
                 adj = 0, col = cfg$muted, cex = 0.73)
  graphics::text(0.035, 0.025, "USDA SNAP inventory + Food Access Research Atlas 2019 / Census urban areas 2020 / Valhalla \u00b7 \u00a9 OSM contributors (ODbL) / NAD83 UTM 16N",
                 adj = 0, col = cfg$muted, cex = 0.69)
  graphics::text(0.035, 0.009, paste0("Retrieved ", snapshot$retrieved_date, " / Sean Thimons / #30DayMapChallenge"),
                 adj = 0, col = cfg$muted, cex = 0.69)
}
if (sys.nframe() == 0L) render_day09()
