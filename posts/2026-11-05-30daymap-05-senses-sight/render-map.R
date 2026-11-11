#!/usr/bin/env Rscript
# Day 05: who can see what. Sightlines from three Ohio River overlooks to the tops of five landmarks,
# over the USGS lidar surface (buildings and trees) and over bare earth. Native R.
# The render reads the cached DEM tile and the committed lidar reductions made by acquire-lidar.R;
# it makes no network requests. Run from the repository root; sourcing only defines functions.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day05_root <- "posts/2026-11-05-30daymap-05-senses-sight"

day05_config <- function() {
  list(
    crs = "EPSG:26916", tile = "USGS_13_n40w085.tif", cache_dir = "data/30daymap/2026/day02",
    eye_m = 1.6, clear_m = 15, footprint_buffer_m = 5, refraction_k = 0.13, radius_m = 6371008.8,
    min_coverage = 0.95, grid_m = 10, water_max_m = 144.5, margin_m = 700,
    # Water seed: the river under the middle of the Roebling main span (OSM way 567780747).
    water_seed = c(-84.50986, 39.09288),
    exaggeration = 2, zlim = c(130, 370),
    profiles = list(c("devou", "gat"), c("mount_echo", "union_terminal"), c("eden", "carew")),
    background = "#121A22", relief = c("#121A22", "#3A4A57"), river = "#2B5468",
    surface = "#6E8291", ground = "#26323C", ink = "#E4DED2", muted = "#8E9BA6",
    colors = c(devou = "#F2C46D", eden = "#EC8C69", mount_echo = "#78C4CB")
  )
}

# Reuse Day 02's verified USGS tile downloader and shared ignored cache, isolated
# in a private environment so Day 02 definitions cannot overwrite Day 05 ones.
day05_tile_helpers <- function() {
  env <- new.env(parent = baseenv())
  sys.source("posts/2026-11-02-30daymap-02-lines/render-map.R", envir = env)
  mget(c("tile_urls", "check_tiff", "acquire_tiles"), envir = env)
}

check_day05_dependencies <- function() {
  needed <- c("terra", "jsonlite", "digest")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing required R packages: ", paste(missing, collapse = ", "),
         ". Load the project-local GIS runtime with `sh scripts/map-r.sh`.", call. = FALSE)
  }
}

# OSM viewpoint nodes behind overlooks.csv. Only used with --refresh-osm.
day05_osm_elements <- function() {
  data.frame(
    key = c("devou", "eden", "mount_echo"),
    label = c("Devou Memorial Overlook", "Eden Park overlook", "Mount Echo Park overlook"),
    park = c("Devou Park", "Eden Park", "Mount Echo Park"),
    osm_id = c(3759254619, 2912935128, 2805238423),
    stringsAsFactors = FALSE
  )
}

refresh_day05_osm <- function(path = file.path(day05_root, "overlooks.csv")) {
  el <- day05_osm_elements()
  rows <- lapply(seq_len(nrow(el)), function(i) {
    url <- sprintf("https://api.openstreetmap.org/api/0.6/node/%.0f.json", el$osm_id[i])
    node <- jsonlite::fromJSON(url, simplifyVector = FALSE)$elements[[1]]
    if (!identical(node$tags$tourism, "viewpoint")) stop("Not a viewpoint: ", url)
    data.frame(el[i, ], lon = round(node$lon, 7), lat = round(node$lat, 7),
               osm_version = node$version, osm_timestamp = node$timestamp,
               retrieved_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  utils::write.csv(out, path, row.names = FALSE, na = "")
  invisible(out)
}

read_day05_points <- function(path = file.path(day05_root, "overlooks.csv")) {
  p <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!identical(p$key, day05_osm_elements()$key) ||
      any(!is.finite(p$lon) | !is.finite(p$lat)) ||
      any(p$lon < -84.7 | p$lon > -84.3 | p$lat < 39 | p$lat > 39.2)) {
    stop("overlooks.csv does not match the Day 05 overlook contract")
  }
  p
}

day05_landmark_keys <- function() c("carew", "gat", "union_terminal", "cathedral", "roebling_n")

# Landmark footprints (WGS84 rings) from the committed GeoJSON.
read_landmarks <- function(path = file.path(day05_root, "landmarks.geojson")) {
  fc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  props <- lapply(fc$features, `[[`, "properties")
  out <- list(
    key = vapply(props, `[[`, "", "key"),
    label = vapply(props, `[[`, "", "label"),
    source = vapply(props, `[[`, "", "source"),
    ring = lapply(fc$features, function(f) do.call(rbind, lapply(f$geometry$coordinates[[1]], unlist)))
  )
  if (!identical(out$key, day05_landmark_keys()) ||
      any(vapply(out$ring, function(r) nrow(r) < 4 || !identical(r[1, ], r[nrow(r), ]), logical(1)))) {
    stop("landmarks.geojson does not match the Day 05 landmark contract")
  }
  out
}

# Even-odd point-in-polygon test for a closed ring (matrix of x, y).
point_in_ring <- function(px, py, ring) {
  inside <- logical(length(px))
  j <- nrow(ring)
  for (i in seq_len(nrow(ring))) {
    xi <- ring[i, 1]
    yi <- ring[i, 2]
    xj <- ring[j, 1]
    yj <- ring[j, 2]
    crosses <- ((yi > py) != (yj > py)) & (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
    inside <- xor(inside, crosses)
    j <- i
  }
  inside
}

# Shortest distance from points to the edges of a closed ring.
ring_distance <- function(px, py, ring) {
  out <- rep(Inf, length(px))
  for (i in seq_len(nrow(ring) - 1L)) {
    a <- ring[i, ]
    ab <- ring[i + 1L, ] - a
    t <- pmin(1, pmax(0, ((px - a[1]) * ab[1] + (py - a[2]) * ab[2]) / sum(ab^2)))
    out <- pmin(out, sqrt((px - a[1] - t * ab[1])^2 + (py - a[2] - t * ab[2])^2))
  }
  out
}

# How much of a landmark rises into view. d, z: the surface along the eye -> top line (NA where
# excluded); eye: absolute eye height; D: distance to the top; top_z, base_z: the landmark's top and
# the ground beneath it. Every surface sample raises the lowest visible height on the landmark to
# where the ray from the eye over that sample meets distance D. Returns metres in view (0 when the
# top is hidden), that lowest height, and the index of the deciding sample (NA if none).
visible_top <- function(d, z, eye, D, top_z, base_z, k = 0.13, radius_m = 6371008.8) {
  stopifnot(length(d) == length(z), all(d > 0), D > 0, top_z >= base_z)
  drop <- function(x) x^2 * (1 - k) / (2 * radius_m)
  ok <- which(is.finite(z) & d < D)
  floor_c <- base_z - drop(D)
  need <- eye + (z[ok] - drop(d[ok]) - eye) * D / d[ok]
  blocker <- NA_integer_
  lowest <- floor_c
  if (length(need) && max(need) > floor_c) {
    blocker <- ok[which.max(need)]
    lowest <- max(need)
  }
  list(visible_m = max(0, top_z - drop(D) - lowest), lowest = lowest, blocker = blocker)
}

day05_to_utm <- function(lonlat, cfg = day05_config()) {
  terra::project(as.matrix(lonlat), from = "EPSG:4269", to = cfg$crs)
}

prepare_day05 <- function(cache_dir, download = FALSE, cfg = day05_config()) {
  check_day05_dependencies()
  # Rendering is offline: keep PROJ from probing its grid CDN, then restore the caller's setting.
  network <- terra::projNetwork()
  suppressMessages(terra::projNetwork(FALSE))
  if (isTRUE(network)) on.exit(suppressMessages(terra::projNetwork(TRUE)), add = TRUE)
  helpers <- day05_tile_helpers()
  # Day 05 reads only the northern tile; the shared downloader fetches both when allowed.
  tile <- file.path(cache_dir, cfg$tile)
  if (!file.exists(tile)) {
    if (!download) stop("Missing raw USGS tile: ", tile, ". Run with --download.", call. = FALSE)
    helpers$acquire_tiles(cache_dir, download = TRUE)
  }
  helpers$check_tiff(tile)
  snapshot <- jsonlite::fromJSON(file.path(day05_root, "source-snapshot.json"), simplifyVector = FALSE)
  if (!identical(digest::digest(tile, algo = "sha256", file = TRUE), snapshot$terrain$sha256)) {
    stop("Terrain tile fingerprint differs from source-snapshot.json. Review the USGS revision before updating it.")
  }
  dem <- terra::rast(tile)
  sample_dem <- function(xy) {
    terra::extract(dem, terra::project(terra::vect(xy, crs = cfg$crs), terra::crs(dem)), method = "bilinear")[[2]]
  }

  # OSM coordinates are WGS84. They are read as NAD83 (EPSG:4269), a ~1 m approximation here,
  # so every transformation stays grid-free and the render makes no PROJ network request.
  points <- read_day05_points()
  oxy <- day05_to_utm(points[c("lon", "lat")])
  rownames(oxy) <- points$key
  landmarks <- read_landmarks()
  rings <- setNames(lapply(landmarks$ring, day05_to_utm), landmarks$key)
  tops <- utils::read.csv(file.path(day05_root, "landmark-tops.csv"), stringsAsFactors = FALSE)
  profiles <- utils::read.csv(file.path(day05_root, "sightline-profiles.csv"), stringsAsFactors = FALSE)
  if (!identical(tops$key, landmarks$key) ||
      nrow(unique(profiles[c("from", "to")])) != nrow(points) * nrow(tops)) {
    stop("Lidar reductions do not match overlooks.csv and landmarks.geojson; rerun acquire-lidar.R")
  }
  tops$base <- sample_dem(as.matrix(tops[c("x", "y")]))
  eye <- sample_dem(oxy) + cfg$eye_m
  names(eye) <- points$key

  # One evaluation per pair: lidar surface (default and sensitivity settings) and bare earth.
  pairs <- unique(profiles[c("from", "to")])
  lines <- lapply(seq_len(nrow(pairs)), function(i) {
    from <- pairs$from[i]
    to <- pairs$to[i]
    p <- profiles[profiles$from == from & profiles$to == to, ]
    top <- tops[tops$key == to, ]
    o <- oxy[from, ]
    D <- sqrt(sum((c(top$x, top$y) - o)^2))
    xy <- cbind(o[1] + p$d / D * (top$x - o[1]), o[2] + p$d / D * (top$y - o[2]))
    ground <- sample_dem(xy)
    near_target <- function(buffer) point_in_ring(xy[, 1], xy[, 2], rings[[to]]) | ring_distance(xy[, 1], xy[, 2], rings[[to]]) <= buffer
    # Missing returns (mostly water) fall back to the bare-earth DEM.
    surface <- ifelse(is.finite(p$z), pmax(p$z, ground), ground)
    evaluate <- function(z, clear, buffer) {
      z[p$d <= clear | near_target(buffer)] <- NA
      visible_top(p$d, z, eye[[from]], D, top$z, top$base, cfg$refraction_k, cfg$radius_m)
    }
    lidar <- evaluate(surface, cfg$clear_m, cfg$footprint_buffer_m)
    bare <- evaluate(ground, cfg$clear_m, cfg$footprint_buffer_m)
    counted <- p$d > cfg$clear_m & !near_target(cfg$footprint_buffer_m)
    b <- lidar$blocker
    row <- data.frame(
      from = from, to = to, dist_km = round(D / 1000, 2), top_m = round(top$z, 1),
      landmark_height_m = round(top$z - top$base, 1), visible_top_m = round(lidar$visible_m, 1),
      visible_share = round(lidar$visible_m / (top$z - top$base), 2),
      blocker_km = if (is.na(b)) NA else round(p$d[b] / 1000, 2),
      blocker_above_ground_m = if (is.na(b)) NA else round(surface[b] - ground[b], 1),
      bare_earth_visible_top_m = round(bare$visible_m, 1),
      visible_top_m_clear30 = round(evaluate(surface, 30, cfg$footprint_buffer_m)$visible_m, 1),
      visible_top_m_buffer3 = round(evaluate(surface, cfg$clear_m, 3)$visible_m, 1),
      visible_top_m_buffer10 = round(evaluate(surface, cfg$clear_m, 10)$visible_m, 1),
      lidar_coverage = round(mean(is.finite(p$z[counted])), 3),
      stringsAsFactors = FALSE
    )
    list(row = row, d = p$d, xy = xy, ground = ground, surface = surface, lowest = lidar$lowest,
         blocker = b, eye = eye[[from]], D = D, top = top)
  })
  matrix <- do.call(rbind, lapply(lines, `[[`, "row"))
  if (any(matrix$lidar_coverage < cfg$min_coverage)) {
    stop("Lidar coverage below ", cfg$min_coverage, " on a sightline; rerun acquire-lidar.R")
  }
  names(lines) <- paste(pairs$from, pairs$to)

  # Plan-view frame: overlooks and landmark tops with margin.
  all_xy <- rbind(oxy, as.matrix(tops[c("x", "y")]))
  frame <- terra::ext(min(all_xy[, 1]) - cfg$margin_m, max(all_xy[, 1]) + cfg$margin_m,
                      min(all_xy[, 2]) - cfg$margin_m, max(all_xy[, 2]) + cfg$margin_m)
  grid <- terra::rast(frame, resolution = cfg$grid_m, crs = cfg$crs)
  window <- terra::project(terra::as.polygons(terra::ext(grid) + 1000, crs = cfg$crs), terra::crs(dem))
  terrain <- terra::project(terra::crop(dem, window, snap = "out"), grid, method = "bilinear")
  if (any(!is.finite(terra::values(terrain)))) stop("Missing terrain inside the map frame")
  # 3DEP flattens water in level steps (about 140.8-144.2 m here); almost no land lies below
  # water_max_m. Keep low cells 8-connected to the water under the Roebling Bridge.
  seed <- day05_to_utm(matrix(cfg$water_seed, ncol = 2))
  low <- terra::classify(terrain <= cfg$water_max_m, cbind(0, NA))
  patches <- terra::patches(low, directions = 8)
  river_id <- terra::extract(patches, seed)[[1]]
  if (!is.finite(river_id)) stop("Water seed is not on the flattened river surface")
  list(points = points, oxy = oxy, landmarks = landmarks, tops = tops, matrix = matrix, lines = lines,
       terrain = terrain, river = patches == river_id, frame = frame, tile = tile)
}

draw_day05 <- function(data, cfg = day05_config()) {
  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op))
  graphics::par(bg = cfg$background, fg = cfg$ink, col.axis = cfg$muted, family = "sans")
  m <- data$matrix
  over <- data$points$key
  marks <- data$tops$key
  short <- c(carew = "Carew Tower", gat = "Great American Tower", union_terminal = "Union Terminal",
             cathedral = "Cathedral Basilica", roebling_n = "Roebling tower")
  overlook_label <- c(devou = "Devou", eden = "Eden Park", mount_echo = "Mount Echo")

  # --- plan view
  graphics::par(fig = c(0, 1, 0.575, 0.93), mar = c(0.5, 1.2, 0.3, 1.2))
  slope <- terra::terrain(data$terrain, "slope", unit = "radians")
  aspect <- terra::terrain(data$terrain, "aspect", unit = "radians")
  shade <- terra::shade(slope, aspect, angle = 40, direction = 315)
  e <- as.vector(data$frame)
  graphics::plot.new()
  graphics::plot.window(e[1:2], e[3:4], asp = 1, xaxs = "i", yaxs = "i")
  left <- graphics::grconvertX(e[1], "user", "ndc") # header and footer align with the map edge
  terra::plot(shade, col = grDevices::colorRampPalette(cfg$relief)(64), legend = FALSE, axes = FALSE,
              add = TRUE, maxcell = 5e6)
  terra::plot(terra::classify(data$river, cbind(0, NA)), col = cfg$river, legend = FALSE, axes = FALSE,
              add = TRUE, maxcell = 5e6)
  for (ln in data$lines) {
    r <- ln$row
    col <- cfg$colors[[r$from]]
    o <- data$oxy[r$from, ]
    if (r$visible_top_m > 0) {
      graphics::segments(o[1], o[2], ln$top$x, ln$top$y, col = col, lwd = 2)
    } else {
      graphics::segments(o[1], o[2], ln$top$x, ln$top$y, col = grDevices::adjustcolor(col, 0.45), lwd = 1, lty = 3)
      graphics::points(ln$xy[ln$blocker, 1], ln$xy[ln$blocker, 2], pch = 4, col = col, cex = 0.9, lwd = 1.6)
    }
  }
  graphics::points(data$tops$x, data$tops$y, pch = 23, cex = 1.2, bg = cfg$ink, col = cfg$background, lwd = 1)
  graphics::text(data$tops$x, data$tops$y, short[marks], pos = 4, offset = 0.5, cex = 0.66, col = cfg$ink)
  graphics::points(data$oxy[, 1], data$oxy[, 2], pch = 21, cex = 1.7, lwd = 1.5,
                   bg = cfg$colors[over], col = cfg$background)
  graphics::text(data$oxy[, 1], data$oxy[, 2], overlook_label[over], pos = c(1, 3, 1), offset = 0.8,
                 col = cfg$colors[over], cex = 0.85, font = 2)
  sx <- e[1] + 400
  sy <- e[3] + 350
  graphics::segments(sx, sy, sx + 1000, sy, col = cfg$ink, lwd = 2)
  graphics::text(sx + 500, sy, "1 km", pos = 3, cex = 0.65, col = cfg$ink)

  # --- matrix: metres of each landmark's top in view
  graphics::par(fig = c(0, 1, 0.435, 0.56), new = TRUE, mar = c(0.3, 7.5, 1.6, 1.2))
  graphics::plot.new()
  graphics::plot.window(c(0.5, length(marks) + 0.5), c(length(over) + 0.5, 0.5), xaxs = "i", yaxs = "i")
  for (i in seq_along(over)) {
    for (j in seq_along(marks)) {
      r <- m[m$from == over[i] & m$to == marks[j], ]
      fill <- if (r$visible_top_m > 0) grDevices::adjustcolor(cfg$colors[[over[i]]], 0.25 + 0.6 * r$visible_share) else NA
      graphics::rect(j - 0.47, i - 0.42, j + 0.47, i + 0.42, col = fill, border = cfg$muted, lwd = 0.5)
      label <- if (r$visible_top_m > 0) sprintf("%.0f of %.0f m", r$visible_top_m, r$landmark_height_m) else "hidden"
      graphics::text(j, i, label, cex = 0.68, col = if (r$visible_top_m > 0) cfg$ink else cfg$muted,
                     font = if (r$visible_top_m > 0) 2 else 1)
    }
  }
  graphics::axis(2, at = seq_along(over), labels = overlook_label[over], las = 1, tick = FALSE, cex.axis = 0.75,
                 col.axis = cfg$ink, mgp = c(0, 0.3, 0))
  graphics::axis(3, at = seq_along(marks), labels = short[marks], tick = FALSE, cex.axis = 0.66,
                 col.axis = cfg$ink, mgp = c(0, 0.2, 0))

  # --- three profiles, shared scale and vertical exaggeration
  xmax <- ceiling(max(vapply(cfg$profiles, function(k) data$lines[[paste(k, collapse = " ")]]$D, 0)) / 500) * 500
  figs <- list(c(0, 1, 0.29, 0.415), c(0, 1, 0.165, 0.29), c(0, 1, 0.04, 0.165))
  for (i in seq_along(cfg$profiles)) {
    k <- cfg$profiles[[i]]
    ln <- data$lines[[paste(k, collapse = " ")]]
    col <- cfg$colors[[k[1]]]
    graphics::par(fig = figs[[i]], new = TRUE, mar = c(1.2, 3.2, 1.2, 1.2))
    graphics::plot.new()
    graphics::plot.window(c(0, xmax), cfg$zlim, xaxs = "i", yaxs = "i", asp = cfg$exaggeration)
    usr <- graphics::par("usr")
    graphics::polygon(c(0, ln$d, ln$D, ln$D, 0), c(usr[3], ln$surface, ln$surface[length(ln$surface)], usr[3], usr[3]),
                      col = cfg$surface, border = NA)
    graphics::polygon(c(0, ln$d, ln$D, ln$D, 0), c(usr[3], ln$ground, ln$ground[length(ln$ground)], usr[3], usr[3]),
                      col = cfg$ground, border = NA)
    base <- ln$top$base
    graphics::segments(ln$D, base, ln$D, ln$top$z, col = cfg$ink, lwd = 1.2)
    if (ln$row$visible_top_m > 0) {
      graphics::segments(ln$D, max(ln$lowest, base), ln$D, ln$top$z, col = col, lwd = 4)
      graphics::segments(0, ln$eye, ln$D, ln$top$z, col = col, lwd = 0.9)
    } else {
      graphics::segments(0, ln$eye, ln$d[ln$blocker], ln$surface[ln$blocker], col = col, lwd = 0.9, lty = 2)
      graphics::points(ln$d[ln$blocker], ln$surface[ln$blocker], pch = 4, col = col, lwd = 1.6)
    }
    graphics::points(0, ln$eye, pch = 21, bg = col, col = cfg$background, cex = 1.1)
    graphics::axis(2, at = c(150, 250, 350), las = 1, cex.axis = 0.6, col = cfg$muted, tcl = -0.2, mgp = c(2, 0.4, 0))
    if (i == length(cfg$profiles)) {
      graphics::axis(1, at = seq(0, xmax, 500), labels = seq(0, xmax, 500) / 1000, cex.axis = 0.6, col = cfg$muted,
                     tcl = -0.2, mgp = c(2, 0.3, 0))
    }
    status <- if (ln$row$visible_top_m > 0) sprintf("top %.0f m in view", ln$row$visible_top_m) else
      sprintf("hidden by something %.0f m tall, %.0f m out", ln$row$blocker_above_ground_m, ln$row$blocker_km * 1000)
    graphics::mtext(sprintf("%s to %s: %s", overlook_label[[k[1]]], short[[k[2]]], status),
                    side = 3, line = 0.1, adj = 0, cex = 0.66, col = col, font = 2)
  }
  # --- header, section labels and footer in the house style of the earlier days (page coordinates)
  graphics::par(fig = c(0, 1, 0, 1), new = TRUE, mar = rep(0, 4))
  graphics::plot.new()
  graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  graphics::text(left, 0.989, "05 / SENSES: SIGHT     \u2022     CINCINNATI AND COVINGTON", adj = 0, cex = 0.8, col = cfg$muted)
  graphics::text(left, 0.9705, "Who can see what?", adj = 0, cex = 1.6, font = 2, col = cfg$ink)
  graphics::text(left, 0.952, "3 overlooks \u00d7 5 landmarks  /  USGS lidar surface: buildings and trees", adj = 0, cex = 0.82,
                 col = cfg$ink)
  graphics::text(left, 0.9375, adj = 0, cex = 0.62, col = cfg$muted, labels = sprintf(
    "Sightlines from a %.1f m eye to the top of each landmark. Solid: top in view. Dotted: hidden; x marks the main obstruction.",
    cfg$eye_m
  ))
  graphics::text(left, 0.568, "METRES OF EACH LANDMARK'S TOP IN VIEW", adj = 0, cex = 0.68, col = cfg$muted)
  graphics::text(left, 0.424, "THREE SIGHTLINES IN PROFILE", adj = 0, cex = 0.68, col = cfg$muted)
  graphics::text(left, 0.024, adj = 0, cex = 0.6, col = cfg$muted, labels = sprintf(
    "Profiles: distance from overlook (km), elevation (m), vertical exaggeration %dx  /  Pale: lidar surface; dark: bare earth",
    cfg$exaggeration
  ))
  graphics::text(left, 0.009, adj = 0, cex = 0.6, col = cfg$muted, labels =
    "USGS 3DEP lidar + DEM  /  \u00a9 OpenStreetMap contributors (ODbL)  /  NAD83 UTM 16N  /  Sean Thimons  /  #30DayMapChallenge")
}

render_day05 <- function(cache_dir = day05_config()$cache_dir,
                         output_dir = file.path(day05_root, "artifacts"), download = FALSE) {
  data <- prepare_day05(cache_dir, download)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  save_plot <- function(open_device) {
    open_device()
    on.exit(grDevices::dev.off())
    draw_day05(data)
  }
  # Cairo devices, as on Days 01, 03 and 04, keep the bullet and multiplication glyphs.
  save_plot(function() grDevices::png(file.path(output_dir, "day05-who-sees-what.png"), width = 2400, height = 3900,
                                      res = 300, bg = day05_config()$background, type = "cairo"))
  save_plot(function() grDevices::cairo_pdf(file.path(output_dir, "day05-who-sees-what.pdf"), width = 8, height = 13,
                                            bg = day05_config()$background))
  utils::write.csv(data$matrix, file.path(output_dir, "sightline-matrix.csv"), row.names = FALSE, na = "")
  message("Day 05 rendered: ", normalizePath(output_dir))
  invisible(data)
}

day05_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste(
    "Usage: sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/render-map.R",
    "[--download] [--refresh-osm]",
    "Run from the repository root. Terrain cache: data/30daymap/2026/day02 (shared with Day 02).",
    "--download permits fetching missing USGS DEM tiles; --refresh-osm rewrites overlooks.csv from the OSM API.",
    "Lidar reductions come from acquire-lidar.R and are committed; this script never downloads lidar.",
    sep = "\n"
  )
  if (any(args %in% c("--help", "-h"))) {
    cat(usage, "\n")
    return(invisible(NULL))
  }
  unknown <- setdiff(args, c("--download", "--refresh-osm"))
  if (length(unknown)) stop("Unknown argument: ", unknown[1], "\n", usage, call. = FALSE)
  if ("--refresh-osm" %in% args) refresh_day05_osm()
  render_day05(download = "--download" %in% args)
}

if (sys.nframe() == 0L) day05_main()
