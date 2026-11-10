#!/usr/bin/env Rscript
# Day 05: bare-earth lines of sight from three Ohio River overlooks. Native R.
# Run from the repository root; sourcing defines functions only, so tests can load it safely.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day05_root <- "posts/2026-11-05-30daymap-05-senses-sight"

day05_config <- function() list(
  crs = "EPSG:26916", tile = "USGS_13_n40w085.tif", cache_dir = "data/30daymap/2026/day02",
  eye_m = 1.6, length_m = 8000, step_m = 10, refraction_k = 0.13, radius_m = 6371008.8,
  grid_m = 10, water_max_m = 144.5, exaggeration = 6, zlim = c(130, 290), margin_m = 600,
  background = "#121A22", relief = c("#121A22", "#3A4A57"), river = "#2B5468",
  ink = "#E4DED2", muted = "#8E9BA6",
  colors = c(devou = "#F2C46D", eden = "#EC8C69", mount_echo = "#78C4CB"))

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
  if (length(missing)) stop("Missing required R packages: ", paste(missing, collapse = ", "),
    ". Load the project-local GIS runtime with `sh scripts/map-r.sh`.", call. = FALSE)
}

# OSM elements behind overlooks.csv. Only used with --refresh-osm.
day05_osm_elements <- function() data.frame(
  role = c("overlook", "overlook", "overlook", "target"),
  key = c("devou", "eden", "mount_echo", "roebling"),
  label = c("Devou Memorial Overlook", "Eden Park overlook", "Mount Echo Park overlook",
            "Roebling Bridge, main span midpoint"),
  park = c("Devou Park", "Eden Park", "Mount Echo Park", NA),
  osm_type = c("node", "node", "node", "way"),
  osm_id = c(3759254619, 2912935128, 2805238423, 567780747),
  stringsAsFactors = FALSE)

refresh_day05_osm <- function(path = file.path(day05_root, "overlooks.csv")) {
  el <- day05_osm_elements()
  rows <- lapply(seq_len(nrow(el)), function(i) {
    suffix <- if (el$osm_type[i] == "way") "/full" else ""
    url <- sprintf("https://api.openstreetmap.org/api/0.6/%s/%.0f%s.json",
                   el$osm_type[i], el$osm_id[i], suffix)
    x <- jsonlite::fromJSON(url, simplifyVector = FALSE)$elements
    main <- Filter(function(e) e$type == el$osm_type[i] && e$id == el$osm_id[i], x)[[1]]
    if (el$osm_type[i] == "node") {
      if (!identical(main$tags$tourism, "viewpoint")) stop("Not a viewpoint: ", url)
      lon <- main$lon; lat <- main$lat
    } else {
      # Midpoint of the two-node main span, in geographic coordinates (span < 0.5 km).
      ends <- Filter(function(e) e$type == "node", x)
      if (length(ends) != 2L || length(main$nodes) != 2L) stop("Expected two-node span: ", url)
      lon <- mean(vapply(ends, `[[`, numeric(1), "lon"))
      lat <- mean(vapply(ends, `[[`, numeric(1), "lat"))
    }
    data.frame(el[i, ], lon = round(lon, 7), lat = round(lat, 7),
               osm_version = main$version, osm_timestamp = main$timestamp,
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
      sum(p$role == "overlook") != 3L || sum(p$role == "target") != 1L ||
      any(!is.finite(p$lon) | !is.finite(p$lat)) ||
      any(p$lon < -84.7 | p$lon > -84.3 | p$lat < 39 | p$lat > 39.2))
    stop("overlooks.csv does not match the Day 05 point contract")
  p
}

# Pure line-of-sight test along one profile. d: horizontal distance from the observer (m),
# z: ground elevation (m). Earth curvature with refraction coefficient k lowers distant
# ground by d^2 (1 - k) / (2 R). A sample is visible when its elevation angle from the eye
# is at least the steepest angle of every nearer sample.
los_visible <- function(d, z, eye_m, k = 0.13, radius_m = 6371008.8) {
  stopifnot(length(d) == length(z), length(d) >= 1L, d[1] == 0, all(diff(d) > 0),
            all(is.finite(z)), is.finite(eye_m), eye_m >= 0)
  visible <- logical(length(d))
  visible[1] <- TRUE  # the observer's own ground point
  if (length(d) == 1L) return(visible)
  eye <- z[1] + eye_m
  zc <- z[-1] - d[-1]^2 * (1 - k) / (2 * radius_m)
  slope <- (zc - eye) / d[-1]
  prior <- c(-Inf, utils::head(cummax(slope), -1L))
  visible[-1] <- slope >= prior
  visible
}

# Sample a straight transect in projected metres from origin through target.
transect_xy <- function(origin, target, length_m, step_m) {
  v <- target - origin
  dist_target <- sqrt(sum(v^2))
  if (!(dist_target > 0 && dist_target < length_m)) stop("Target must lie inside the transect")
  u <- v / dist_target
  d <- seq(0, length_m, by = step_m)
  list(d = d, x = origin[1] + d * u[1], y = origin[2] + d * u[2], target_d = dist_target)
}

day05_runs <- function(values) {
  r <- rle(values)
  ends <- cumsum(r$lengths)
  data.frame(value = r$values, start = ends - r$lengths + 1L, end = ends)
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
  snapshot <- jsonlite::fromJSON(file.path(day05_root, "source-snapshot.json"),
                                 simplifyVector = FALSE)
  if (!identical(digest::digest(tile, algo = "sha256", file = TRUE), snapshot$terrain$sha256))
    stop("Terrain tile fingerprint differs from source-snapshot.json. Review the USGS revision before updating it.")
  points <- read_day05_points()
  # OSM coordinates are WGS84. They are read as NAD83 (EPSG:4269), a ~1 m approximation
  # here, so every transformation stays grid-free and the render makes no PROJ network request.
  xy <- terra::crds(terra::project(terra::vect(as.matrix(points[c("lon", "lat")]),
                                               crs = "EPSG:4269"), cfg$crs))
  rownames(xy) <- points$key
  dem <- terra::rast(tile)
  target_xy <- xy["roebling", ]
  lines <- lapply(points$key[points$role == "overlook"], function(key) {
    t <- transect_xy(xy[key, ], target_xy, cfg$length_m, cfg$step_m)
    t$key <- key
    t
  })
  names(lines) <- vapply(lines, `[[`, "", "key")
  all_x <- unlist(lapply(lines, `[[`, "x")); all_y <- unlist(lapply(lines, `[[`, "y"))
  frame <- terra::ext(min(all_x) - cfg$margin_m, max(all_x) + cfg$margin_m,
                      min(all_y) - cfg$margin_m, max(all_y) + cfg$margin_m)
  grid <- terra::rast(frame, resolution = cfg$grid_m, crs = cfg$crs)
  # Crop in geographic coordinates first (with margin) so the one-degree tile is never projected whole.
  window <- terra::project(terra::as.polygons(terra::ext(grid) + 1000, crs = cfg$crs),
                           terra::crs(dem))
  terrain <- terra::project(terra::crop(dem, window, snap = "out"), grid, method = "bilinear")
  if (any(!is.finite(terra::values(terrain)))) stop("Missing terrain inside the map frame")
  sample_z <- function(x, y) {
    pts <- terra::project(terra::vect(cbind(x, y), crs = cfg$crs), terra::crs(dem))
    terra::extract(dem, pts, method = "bilinear")[[2]]
  }
  # 3DEP flattens water in level steps (about 140.8-144.2 m in this frame); almost no land lies
  # below water_max_m. Keep low cells 8-connected to the water under the bridge.
  pool <- sample_z(target_xy[1], target_xy[2])
  if (!(pool <= cfg$water_max_m)) stop("Bridge target is not on the flattened water surface")
  low <- terra::classify(terrain <= cfg$water_max_m, cbind(0, NA))
  patches <- terra::patches(low, directions = 8)
  river_id <- terra::extract(patches, matrix(target_xy, ncol = 2))[[1]]
  if (!is.finite(river_id)) stop("Bridge target is not on the flattened water surface")
  river <- patches == river_id
  profiles <- lapply(lines, function(t) {
    z <- sample_z(t$x, t$y)
    if (any(!is.finite(z))) stop("Missing elevation on transect: ", t$key)
    on_river <- terra::extract(river, cbind(t$x, t$y))[[1]]
    on_river[is.na(on_river)] <- FALSE
    vis <- los_visible(t$d, z, cfg$eye_m, cfg$refraction_k, cfg$radius_m)
    data.frame(key = t$key, d = t$d, x = t$x, y = t$y, z = z, visible = vis,
               river = as.logical(on_river))
  })
  summary <- do.call(rbind, lapply(names(profiles), function(key) {
    p <- profiles[[key]]
    t <- lines[[key]]
    at_target <- which.min(abs(p$d - t$target_d))
    data.frame(key = key, label = points$label[points$key == key],
               ground_elev_m = round(p$z[1], 1), eye_m = cfg$eye_m,
               target_dist_m = round(t$target_d), target_visible = p$visible[at_target],
               ground_visible_pct = round(100 * mean(p$visible[-1]), 1),
               river_samples = sum(p$river),
               river_visible_pct = round(100 * mean(p$visible[p$river]), 1),
               stringsAsFactors = FALSE)
  }))
  list(points = points, xy = xy, profiles = profiles, summary = summary, terrain = terrain,
       river = river, pool_m = pool, frame = frame, tile = tile)
}

draw_day05 <- function(data, cfg = day05_config()) {
  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op))
  graphics::par(bg = cfg$background, fg = cfg$ink, col.axis = cfg$muted, family = "sans")
  keys <- names(data$profiles)
  # Panel geometry (figure fractions). Plan view on top, three profiles below.
  plan_fig <- c(0, 1, 0.46, 1)
  prof_figs <- lapply(1:3, function(i) c(0, 1, 0.44 - i * 0.125, 0.44 - (i - 1) * 0.125))
  # --- plan view
  graphics::par(fig = plan_fig, mar = c(0.6, 1.2, 3.4, 1.2))
  slope <- terra::terrain(data$terrain, "slope", unit = "radians")
  aspect <- terra::terrain(data$terrain, "aspect", unit = "radians")
  shade <- terra::shade(slope, aspect, angle = 40, direction = 315)
  e <- as.vector(data$frame)
  graphics::plot.new()
  graphics::plot.window(e[1:2], e[3:4], asp = 1, xaxs = "i", yaxs = "i")
  ramp <- grDevices::colorRampPalette(cfg$relief)(64)
  terra::plot(shade, col = ramp, legend = FALSE, axes = FALSE, add = TRUE, maxcell = 5e6)
  terra::plot(terra::classify(data$river, cbind(0, NA)), col = cfg$river, legend = FALSE,
              axes = FALSE, add = TRUE, maxcell = 5e6)
  for (key in keys) {
    p <- data$profiles[[key]]
    runs <- day05_runs(p$visible)
    for (j in seq_len(nrow(runs))) {
      idx <- seq(max(1L, runs$start[j] - 1L), runs$end[j])
      graphics::lines(p$x[idx], p$y[idx], col = if (runs$value[j]) cfg$colors[[key]] else
        grDevices::adjustcolor(cfg$colors[[key]], 0.35),
        lwd = if (runs$value[j]) 2.6 else 1.1, lty = if (runs$value[j]) 1 else 3)
    }
  }
  over <- data$points$key[data$points$role == "overlook"]
  graphics::points(data$xy[over, 1], data$xy[over, 2], pch = 21, cex = 1.6, lwd = 1.5,
                   bg = cfg$colors[over], col = cfg$background)
  graphics::points(data$xy["roebling", 1], data$xy["roebling", 2], pch = 23, cex = 1.3,
                   bg = cfg$ink, col = cfg$background, lwd = 1.2)
  # Label offsets in metres (dx, dy, horizontal adj) keep text inside the frame and off the lines.
  nudge <- list(devou = c(0, -380, 0.5), eden = c(0, 380, 0.5), mount_echo = c(-150, -380, 0),
                roebling = c(220, -260, 0))
  labels <- setNames(data$points$label, data$points$key)
  labels["roebling"] <- "Roebling Bridge"
  for (key in names(nudge)) {
    n <- nudge[[key]]
    graphics::text(data$xy[key, 1] + n[1], data$xy[key, 2] + n[2], labels[[key]],
                   adj = c(n[3], 0.5), cex = if (key == "roebling") 0.72 else 0.8,
                   font = if (key == "roebling") 1 else 2,
                   col = if (key == "roebling") cfg$ink else cfg$colors[[key]])
  }
  graphics::mtext("Three overlooks, one bridge", side = 3, line = 1.7, adj = 0, cex = 1.35,
                  font = 2, col = cfg$ink)
  graphics::mtext(sprintf("Bare-earth sightlines through the bridge, %.1f m eye height. Solid: ground in view. Dotted: hidden.", cfg$eye_m),
                  side = 3, line = 0.5, adj = 0, cex = 0.72, col = cfg$muted)
  # 2 km scale bar, bottom left.
  sx <- e[1] + 400; sy <- e[3] + 400
  graphics::segments(sx, sy, sx + 2000, sy, col = cfg$ink, lwd = 2)
  graphics::text(sx + 1000, sy, "2 km", pos = 3, cex = 0.7, col = cfg$ink)
  # --- profiles, shared horizontal scale and fixed vertical exaggeration
  zlim <- cfg$zlim
  for (i in seq_along(keys)) {
    key <- keys[i]
    p <- data$profiles[[key]]
    s <- data$summary[data$summary$key == key, ]
    graphics::par(fig = prof_figs[[i]], new = TRUE, mar = c(1.4, 3.2, 1.3, 1.2))
    graphics::plot.new()
    graphics::plot.window(c(0, cfg$length_m), zlim, xaxs = "i", yaxs = "i",
                          asp = cfg$exaggeration)
    usr <- graphics::par("usr")
    graphics::polygon(c(p$d, rev(p$d)), c(p$z, rep(usr[3], nrow(p))),
                      col = grDevices::adjustcolor(cfg$relief[2], 0.9), border = NA)
    river_runs <- day05_runs(p$river)
    for (j in which(river_runs$value)) {
      idx <- river_runs$start[j]:river_runs$end[j]
      graphics::polygon(c(p$d[idx], rev(p$d[idx])), c(p$z[idx], rep(usr[3], length(idx))),
                        col = cfg$river, border = NA)
    }
    runs <- day05_runs(p$visible)
    for (j in seq_len(nrow(runs))) {
      idx <- seq(max(1L, runs$start[j] - 1L), runs$end[j])
      graphics::lines(p$d[idx], p$z[idx], col = if (runs$value[j]) cfg$colors[[key]] else
        grDevices::adjustcolor(cfg$colors[[key]], 0.35),
        lwd = if (runs$value[j]) 2.2 else 1, lty = if (runs$value[j]) 1 else 3)
    }
    graphics::points(0, p$z[1] + cfg$eye_m, pch = 21, bg = cfg$colors[[key]],
                     col = cfg$background, cex = 1.2)
    graphics::abline(v = s$target_dist_m, col = cfg$ink, lty = 2, lwd = 0.7)
    graphics::axis(2, at = c(150, 200, 250), las = 1, cex.axis = 0.62, col = cfg$muted,
                   tcl = -0.2, mgp = c(2, 0.4, 0))
    if (i == length(keys))
      graphics::axis(1, at = seq(0, cfg$length_m, 1000), labels = 0:8, cex.axis = 0.62,
                     col = cfg$muted, tcl = -0.2, mgp = c(2, 0.3, 0))
    graphics::mtext(sprintf("%s: %s%% of ground in view; water under the bridge %s",
                            s$label, format(s$ground_visible_pct, nsmall = 1),
                            if (s$target_visible) "visible" else "hidden"),
                    side = 3, line = 0.15, adj = 0, cex = 0.72, col = cfg$colors[[key]], font = 2)
  }
  graphics::par(fig = c(0, 1, 0, 0.06), new = TRUE, mar = rep(0, 4))
  graphics::plot.new()
  graphics::text(0.012, 0.6, adj = 0, cex = 0.6, col = cfg$muted, labels = sprintf(
    "Distance from overlook (km); elevation (m), vertical exaggeration %dx. Blue: water. Dashed line: bridge. Curvature and refraction (k = %.2f) applied.",
    cfg$exaggeration, cfg$refraction_k))
  graphics::text(0.012, 0.2, adj = 0, cex = 0.6, col = cfg$muted, labels =
    "Terrain: USGS 3DEP 1/3 arc-second DEM (bare earth; no buildings or trees). Points: © OpenStreetMap contributors, ODbL. NAD83 / UTM 16N.")
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
  save_plot(function() grDevices::png(file.path(output_dir, "day05-three-overlooks.png"),
    width = 2400, height = 3600, res = 300, bg = day05_config()$background))
  save_plot(function() grDevices::pdf(file.path(output_dir, "day05-three-overlooks.pdf"),
    width = 8, height = 12, bg = day05_config()$background, timestamp = FALSE))
  utils::write.csv(data$summary, file.path(output_dir, "sightline-summary.csv"), row.names = FALSE)
  message("Day 05 rendered: ", normalizePath(output_dir))
  invisible(data)
}

day05_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste("Usage: sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/render-map.R",
    "[--download] [--refresh-osm]",
    "Run from the repository root. Terrain cache: data/30daymap/2026/day02 (shared with Day 02).",
    "--download permits fetching missing USGS tiles; --refresh-osm rewrites overlooks.csv from the OSM API.",
    sep = "\n")
  if (any(args %in% c("--help", "-h"))) { cat(usage, "\n"); return(invisible(NULL)) }
  unknown <- setdiff(args, c("--download", "--refresh-osm"))
  if (length(unknown)) stop("Unknown argument: ", unknown[1], "\n", usage, call. = FALSE)
  if ("--refresh-osm" %in% args) refresh_day05_osm()
  render_day05(download = "--download" %in% args)
}

if (sys.nframe() == 0L) day05_main()
