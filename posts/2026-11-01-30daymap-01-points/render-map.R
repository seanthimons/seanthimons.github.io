#!/usr/bin/env Rscript
# Native R acquisition, projection and rendering; no GIS runtime required.
day01_config <- function() list(
  bounds = c(west = -76, east = -62, south = -28, north = -14),
  band = c(-24, -20), parallel = -21, radius_km = 6371.0088,
  background = "#101D29", land = "#2C3B44", ink = "#E6E0D4", muted = "#9DAEB9",
  colors = c("#F5CD78", "#EC8C69", "#CE638B", "#897AC1", "#68B8CD"))

day01_urls <- function() c(
  earthquakes = paste0("https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv",
    "&starttime=2021-01-01&endtime=2025-12-31T23:59:59.999",
    "&minlatitude=-28&maxlatitude=-14&minlongitude=-76&maxlongitude=-62",
    "&minmagnitude=4&mindepth=0&maxdepth=700&eventtype=earthquake&orderby=time-asc"),
  coastline = paste0("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/",
    "ca96624a56bd078437bca8184e78163e5039ad19/geojson/ne_110m_coastline.geojson"),
  land = paste0("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/",
    "ca96624a56bd078437bca8184e78163e5039ad19/geojson/ne_110m_land.geojson"))

project_day01 <- function(lon, lat, cfg = day01_config()) {
  # Spherical equidistant cylindrical, 21 S standard parallel, 76 W origin.
  cbind(x = cfg$radius_km * (lon - cfg$bounds['west']) * pi / 180 *
          cos(cfg$parallel * pi / 180),
        y = cfg$radius_km * (lat - cfg$parallel) * pi / 180)
}

read_day01 <- function(cache_dir, download = FALSE) {
  urls <- day01_urls()
  paths <- file.path(cache_dir, c("earthquakes.csv", "coastline.geojson", "land.geojson"))
  names(paths) <- names(urls)
  for (i in seq_along(paths)) if (!file.exists(paths[i])) {
    if (!download) stop("Missing cached source: ", paths[i], "; run render-map.R --download")
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    tmp <- paste0(paths[i], ".part")
    tryCatch({
      status <- utils::download.file(urls[i], tmp, mode = "wb", method = "libcurl")
      if (status != 0 || !file.rename(tmp, paths[i])) stop("Download failed: ", urls[i])
    }, finally = if (file.exists(tmp)) unlink(tmp))
  }
  snapshot <- jsonlite::fromJSON("posts/2026-11-01-30daymap-01-points/source-snapshot.json")
  hashes <- vapply(paths, digest::digest, character(1), algo = "sha256", file = TRUE)
  if (!identical(unname(hashes), unname(unlist(snapshot$sha256))))
    stop("Source fingerprint differs from reviewed snapshot. Inspect catalog revisions before updating source-snapshot.json.")
  d <- utils::read.csv(paths['earthquakes'], stringsAsFactors = FALSE)
  needed <- c("id", "longitude", "latitude", "depth", "mag", "time", "type")
  if (!all(needed %in% names(d)) || !nrow(d) || nrow(d) >= 20000 || anyDuplicated(d$id))
    stop("Invalid, duplicate, empty, or possibly truncated earthquake catalog")
  numeric <- as.matrix(d[c("longitude", "latitude", "depth", "mag")])
  times <- as.POSIXct(d$time, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
  if (any(!is.finite(numeric)) || anyNA(times) ||
      any(times < as.POSIXct("2021-01-01", tz = "UTC") |
          times >= as.POSIXct("2026-01-01", tz = "UTC")) ||
      any(d$longitude < -76 | d$longitude > -62 | d$latitude < -28 |
          d$latitude > -14 | d$depth < 0 | d$depth > 700 | d$mag < 4) ||
      any(d$type != "earthquake")) stop("Catalog outside query contract")
  coast <- jsonlite::fromJSON(paths['coastline'], simplifyVector = FALSE)
  if (!identical(coast$type, "FeatureCollection")) stop("Invalid coastline GeoJSON")
  lines <- lapply(coast$features, function(f) {
    if (!identical(f$geometry$type, "LineString")) stop("Expected coastline LineString")
    do.call(rbind, lapply(f$geometry$coordinates, unlist))
  })
  land <- jsonlite::fromJSON(paths['land'], simplifyVector = FALSE)
  if (!identical(land$type, "FeatureCollection")) stop("Invalid land GeoJSON")
  polygons <- list()
  for (feature in land$features) {
    geometry <- feature$geometry
    pieces <- switch(geometry$type, Polygon = list(geometry$coordinates),
      MultiPolygon = geometry$coordinates, stop("Expected land polygon geometry"))
    for (piece in pieces) {
      rings <- lapply(piece, function(ring) do.call(rbind, lapply(ring, unlist)))
      polygons[[length(polygons) + 1L]] <- rings
    }
  }
  list(events = d, coast = lines, land = polygons, paths = paths)
}

render_day01 <- function(cache_dir = "data/30daymap/2026/day01",
                         output_dir = "posts/2026-11-01-30daymap-01-points/artifacts",
                         download = FALSE) {
  stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("digest", quietly = TRUE))
  cfg <- day01_config()
  inputs <- read_day01(cache_dir, download)
  d <- inputs$events
  xy <- project_day01(d$longitude, d$latitude, cfg)
  selected <- d$latitude >= cfg$band[1] & d$latitude <= cfg$band[2]
  if (!any(selected)) stop("Empty section")
  width <- unname(project_day01(-62, -21)[1, 'x'])
  ylim <- project_day01(c(-76, -76), c(-28, -14))[, 'y']
  band_y <- project_day01(c(-76, -76), cfg$band)[, 'y']
  colors <- grDevices::colorRampPalette(cfg$colors)(701)[pmin(701, floor(d$depth) + 1)]
  # Fixed point area: location and depth carry the story, magnitude is a filter.
  draw <- function() {
    graphics::par(bg = cfg$background, fg = cfg$ink, col.axis = cfg$muted,
      col.lab = cfg$muted, family = "sans", xaxs = "i", yaxs = "i")
    panel <- function(bottom, top) {
      par(fig = c(.1, .94, bottom, top), mar = c(0, 0, 0, 0), new = TRUE)
    }
    par(fig = c(.1, .94, .925, .99), mar = rep(0, 4))
    plot.new(); plot.window(c(0, 1), c(0, 1))
    text(0, .85, "01 / POINTS     •     CENTRAL ANDES", adj = 0, cex = .85, col = cfg$muted)
    text(0, .48, "The continent beneath the continent", adj = 0, cex = 1.72, font = 2)
    text(0, .12, sprintf("%s earthquakes  /  M ≥ 4  /  2021–2025", format(nrow(d), big.mark = ",")),
      adj = 0, cex = .95)
    panel(.90 - (8.4 * diff(ylim) / width) / (3000 / 180), .90)
    plot(NA, xlim = c(0, width), ylim = ylim, axes = FALSE, xlab = "", ylab = "")
    # Real land polygons, including interior rings, sit below all map marks.
    for (polygon in inputs$land) {
      ring <- polygon[[1]]
      if (max(ring[, 1]) < cfg$bounds['west'] || min(ring[, 1]) > cfg$bounds['east'] ||
          max(ring[, 2]) < cfg$bounds['south'] || min(ring[, 2]) > cfg$bounds['north']) next
      projected <- lapply(polygon, function(ring) {
        rbind(project_day01(ring[, 1], ring[, 2]), c(NA_real_, NA_real_))
      })
      path <- do.call(rbind, projected)
      path <- path[-nrow(path), , drop = FALSE]
      polypath(path[, 1], path[, 2], col = cfg$land, border = NA, rule = "evenodd")
    }
    abline(v = project_day01(seq(-76, -62, 2), -21)[, 'x'],
      h = project_day01(-76, seq(-28, -14, 2))[, 'y'], col = "#24323F", lwd = .5)
    for (line in inputs$coast) {
      p <- project_day01(line[, 1], line[, 2]); lines(p, col = "#7E909C", lwd = .9)
    }
    rect(0, band_y[1], width, band_y[2], col = "#FFFFFF09", border = NA)
    points(xy, pch = 16, cex = .38, col = adjustcolor(colors, alpha.f = .65))
    abline(h = band_y, col = "#D4D9D9", lty = 2, lwd = .8)
    axis(2, at = project_day01(-76, seq(-28, -14, 2))[, 'y'],
      labels = paste0(abs(seq(-28, -14, 2)), "°S"), las = 1, tick = FALSE, cex.axis = .8)
    text(35, mean(band_y), "A", adj = 0, font = 2)
    text(width - 35, mean(band_y), "A′", adj = 1, font = 2)
    text(project_day01(-74.3, -25), "PACIFIC\nOCEAN", col = cfg$muted, cex = .85, font = 3)
    text(project_day01(-65, -16), "SOUTH AMERICA", col = cfg$muted, cex = .85)
    text(project_day01(-69, -26.8), "Coastline: Natural Earth · 1:110m", cex = .65, col = cfg$muted)
    panel(.305, .35); plot.new(); plot.window(c(0, 1), c(0, 1))
    xs <- seq(.01, .57, length.out = 701)
    rect(xs[-701], .55, xs[-1], .8, col = colorRampPalette(cfg$colors)(700), border = NA)
    text(seq(.01, .57, length.out = 5), .32, c("0", "175", "350", "525", "700 km"), cex = .75)
    text(.64, .66, "COLOR = FOCAL DEPTH", adj = 0, cex = .78, col = cfg$muted)
    text(.01, .15, sprintf("A–A′  /  24–20°S band  /  %s events projected east–west", sum(selected)),
      adj = 0, cex = .85)
    panel(.06, .06 + (8.4 * 700 / width) / (3000 / 180))
    plot(NA, xlim = c(0, width), ylim = c(700, 0), axes = FALSE, xlab = "", ylab = "")
    abline(h = seq(0, 700, 100), col = "#293744", lwd = .5)
    abline(v = project_day01(seq(-76, -62, 2), -21)[, 'x'], col = "#24323F", lwd = .5)
    points(xy[selected, 'x'], d$depth[selected], pch = 16, cex = .45,
      col = adjustcolor(colors[selected], alpha.f = .8))
    axis(2, at = c(0, 200, 400, 600), labels = c("0", "200", "400", "600"),
      las = 1, tick = FALSE, cex.axis = .8)
    mtext("Depth (km)", side = 2, line = 2.8, cex = .7)
    axis(1, at = project_day01(seq(-76, -62, 2), -21)[, 'x'],
      labels = paste0(abs(seq(-76, -62, 2)), "°W"), tick = FALSE, cex.axis = .8)
    mtext("WEST                 Longitude / same horizontal scale                 EAST", side = 1, line = 1.8, cex = .7)
    panel(.002, .032); plot.new(); plot.window(c(0, 1), c(0, 1))
    text(0, .7, "No vertical exaggeration · spherical equidistant cylindrical at 21°S", adj = 0, cex = .75, col = cfg$muted)
    text(0, .26, "USGS ComCat + Natural Earth  /  Sean Thimons  /  #30DayMapChallenge", adj = 0, cex = .75, col = cfg$muted)
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  png <- file.path(output_dir, "day01-andes-depth.png")
  grDevices::png(png, width = 1800, height = 3000, res = 180, type = "cairo")
  tryCatch(draw(), finally = grDevices::dev.off())
  pdf <- file.path(output_dir, "day01-andes-depth.pdf")
  grDevices::cairo_pdf(pdf, width = 10, height = 3000 / 180, onefile = FALSE)
  tryCatch(draw(), finally = grDevices::dev.off())
  provenance <- list(urls = day01_urls(),
    retrieved_utc = jsonlite::fromJSON("posts/2026-11-01-30daymap-01-points/source-snapshot.json")$retrieved_utc,
    sha256 = vapply(inputs$paths, digest::digest, character(1), algo = "sha256", file = TRUE),
    config = cfg, count = nrow(d), section_count = sum(selected),
    depth_range_km = range(d$depth), R = R.version.string,
    packages = vapply(c("jsonlite", "digest"), function(p) as.character(utils::packageVersion(p)), character(1)))
  dput(provenance, file.path(output_dir, "provenance.R"))
  invisible(provenance)
}
if (sys.nframe() == 0L) render_day01(download = "--download" %in% commandArgs(TRUE))
