#!/usr/bin/env Rscript
# Offline renderer. Run acquire-data.R --download explicitly to rebuild the inputs.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day06_root <- "posts/2026-11-06-30daymap-06-vintage"
day06_cache <- "data/30daymap/2026/day06"
day06_config <- function() list(
  bounds = c(-84.549, -84.479, 39.069, 39.144), crs = "EPSG:26916",
  paper = "#F4E9CD", ink = "#282E2B", muted = "#6D7164", accent = "#8E3028"
)

read_day06_breweries <- function(path = file.path(day06_root, "breweries.csv")) {
  p <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c("name", "city", "address_text", "lon", "lat", "placed_by", "in_1903_source",
                "source_url", "osm_url", "retrieved_date", "placement_note")
  if (!all(required %in% names(p)) || !nrow(p) || anyDuplicated(p$name) ||
      any(!is.finite(p$lon) | !is.finite(p$lat)) ||
      !all(p$placed_by %in% c("queen_city_address", "osm_feature", "osm_intersection")) ||
      !is.logical(p$in_1903_source) || anyNA(p$in_1903_source)) stop("Invalid brewery reduction")
  b <- day06_config()$bounds
  if (any(p$lon < b[1] | p$lon > b[2] | p$lat < b[3] | p$lat > b[4])) stop("Brewery outside map extent")
  p
}

# Densify geographic edges before projection, including the sheets' shared neatline.
day06_rectangle <- function(bounds, crs = "EPSG:4267") {
  x <- seq(bounds[1], bounds[2], length.out = 101)
  y <- seq(bounds[3], bounds[4], length.out = 101)
  ring <- rbind(cbind(x, y[1]), cbind(tail(x, 1), y), cbind(rev(x), tail(y, 1)),
                cbind(x[1], rev(y)), c(x[1], y[1]))
  terra::vect(ring, type = "polygons", crs = crs)
}

prepare_day06_basemap <- function() {
  terra::projNetwork(FALSE)
  bounds <- day06_config()$bounds
  roi <- terra::project(day06_rectangle(bounds, "EPSG:4326"), day06_config()$crs)
  grid <- terra::rast(terra::ext(roi), resolution = 6, crs = day06_config()$crs)
  sheets <- lapply(c("west", "east"), function(side) {
    r <- terra::rast(file.path(day06_cache, paste0(side, ".tif")))
    # Trust the embedded NAD27 Polyconic definitions, never assign a guessed EPSG.
    if (!grepl("NAD27", terra::crs(r)) || !grepl("Polyconic", terra::crs(r))) stop("Unexpected sheet CRS")
    neatline <- if (side == "west") c(-84.75, -84.5, 39, 39.25) else c(-84.5, -84.25, 39, 39.25)
    clip <- terra::project(day06_rectangle(neatline), terra::crs(r))
    # Crop first to avoid resampling the full sheet, then mask off its printed collar.
    crop <- terra::crop(r, terra::project(roi, terra::crs(r)), snap = "out")
    crop <- terra::mask(crop, clip)
    terra::project(crop, grid, method = "bilinear")
  })
  r <- terra::mosaic(sheets[[1]], sheets[[2]], fun = "mean")
  terra::writeRaster(r, file.path(day06_cache, "mosaic.tif"), overwrite = TRUE,
                     datatype = "INT1U", gdal = c("COMPRESS=DEFLATE"))
  invisible(r)
}

verify_day06_inputs <- function() {
  snapshot <- jsonlite::read_json(file.path(day06_root, "source-snapshot.json"), simplifyVector = TRUE)
  for (i in seq_len(nrow(snapshot$render_inputs))) {
    x <- snapshot$render_inputs[i, ]
    if (!file.exists(x$path) || digest::digest(file = x$path, algo = "sha256") != x$sha256)
      stop("Missing or changed input: ", x$path, ". Run acquire-data.R --download and review changes.")
  }
}

render_day06 <- function() {
  terra::projNetwork(FALSE)
  verify_day06_inputs()
  p <- read_day06_breweries()
  map <- terra::rast(file.path(day06_cache, "mosaic.tif"))
  xy <- terra::crds(terra::project(terra::vect(p, geom = c("lon", "lat"), crs = "EPSG:4326"), terra::crs(map)))
  cfg <- day06_config()
  out <- file.path(day06_root, "artifacts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  draw <- function() draw_day06(map, p, xy, cfg)
  grDevices::png(file.path(out, "day06-before-the-dry-years.png"), width = 2700, height = 3900,
                  res = 300, type = "cairo", bg = cfg$paper)
  tryCatch(draw(), finally = grDevices::dev.off())
  grDevices::cairo_pdf(file.path(out, "day06-before-the-dry-years.pdf"), width = 9, height = 13, bg = cfg$paper)
  tryCatch(draw(), finally = grDevices::dev.off())
  dput(list(R = R.version.string, terra = as.character(utils::packageVersion("terra")),
            crs = terra::crs(map), bounds = cfg$bounds, source_pixels_m = 5.291667,
            display_pixels_m = 6), file.path(out, "provenance.R"))
  invisible(p)
}


# Page overlay follows Day 05; the scan supplies the color and texture.
draw_day06 <- function(map, p, xy, cfg = day06_config()) {
  graphics::par(bg = cfg$paper, family = "sans", mar = rep(0, 4), xpd = NA)
  graphics::par(fig = c(0.055, 0.945, 0.255, 0.89))
  terra::plotRGB(map, r = 1, g = 2, b = 3, scale = 255, axes = FALSE, asp = 1,
                 maxcell = terra::ncell(map), bgalpha = 0)
  shape <- c(queen_city_address = 21, osm_feature = 23, osm_intersection = 24)
  # Offsets are annotation positions only: leader lines preserve the actual point.
  dx <- c(380, -500, -420, -540, -500, 380, -450, 400, 400, 400, -420, 430, 370)
  dy <- c(-80, -180, 280, 200, 280, 120, 0, -100, 80, -80, -250, -200, 240)
  labels <- xy + cbind(dx, dy)
  graphics::segments(xy[,1], xy[,2], labels[,1], labels[,2], col = cfg$accent, lwd = 0.8)
  graphics::points(xy, pch = shape[p$placed_by], bg = cfg$accent, col = cfg$paper, cex = 1.3, lwd = 0.8)
  graphics::points(labels, pch = 21, bg = cfg$paper, col = cfg$accent, cex = 1.9, lwd = 0.7)
  graphics::text(labels, labels = seq_len(nrow(p)), cex = 0.62, font = 2, col = cfg$accent)
  e <- as.vector(terra::ext(map))
  # Metric scale belongs to the projected display, not to the resized paper scan.
  sx <- e[1] + 350; sy <- e[3] + 350
  graphics::rect(sx - 120, sy - 170, sx + 1250, sy + 280, col = cfg$paper, border = NA)
  graphics::segments(sx, sy, sx + 1000, sy, lwd = 2, col = cfg$ink)
  graphics::segments(c(sx, sx + 1000), sy - 45, c(sx, sx + 1000), sy + 45, col = cfg$ink)
  graphics::text(sx + 500, sy + 150, "1 km", cex = 0.65, col = cfg$ink)
  graphics::par(fig = c(0, 1, 0, 1), new = TRUE, mar = rep(0, 4))
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  left <- 0.065
  graphics::text(left, 0.972, "06 / VINTAGE     \u2022     CINCINNATI", adj = 0, cex = 0.85, col = cfg$muted)
  graphics::text(left, 0.94, "Before the dry years", adj = 0, cex = 2, font = 2, col = cfg$ink)
  graphics::text(left, 0.912, sprintf("%d brewery sites around 1914  /  two USGS sheets at 1:62,500", nrow(p)),
                 adj = 0, cex = 0.9, col = cfg$ink)
  graphics::text(left, 0.239, "PLACEMENT EVIDENCE  /  POINTS ARE APPROXIMATE SITE LOCATIONS", adj = 0,
                 cex = 0.65, col = cfg$muted)
  graphics::legend(left, 0.227, legend = c("Address / block", "OSM historical feature", "Street intersection"),
                   pch = c(21, 23, 24), pt.bg = cfg$accent, col = cfg$accent, text.col = cfg$ink,
                   horiz = TRUE, bty = "n", cex = 0.7, x.intersp = 0.7, y.intersp = 1.1)
  graphics::text(left, 0.187, "BREWERIES  /  * FIRM NAMED IN THE 1903 BREWING HISTORY", adj = 0,
                 cex = 0.65, col = cfg$muted)
  for (i in seq_len(nrow(p))) {
    col <- if (i <= 7) 0 else 1; row <- if (i <= 7) i else i - 7
    label <- sprintf("%02d  %s%s", i, p$name[i], if (p$in_1903_source[i]) " *" else "")
    if (p$city[i] != "Cincinnati") label <- paste0(label, " \u00b7 ", p$city[i])
    graphics::text(left + col * 0.46, 0.184 - row * 0.017, label, adj = 0, cex = 0.73, col = cfg$ink)
  }
  graphics::text(left, 0.044, "13 placements; 10 unresolved firms omitted. Historical numbers and modern street geometry do not always agree.",
                 adj = 0, cex = 0.63, col = cfg$muted)
  graphics::text(left, 0.024, "USGS 1914 editions (public domain) / Queen City Chapter / 1903 brewing history / \u00a9 OSM contributors (ODbL)",
                 adj = 0, cex = 0.61, col = cfg$muted)
  graphics::text(left, 0.01, "NAD83 / UTM 16N display  \u00b7  Retrieved 11 Nov 2026  /  Sean Thimons / #30DayMapChallenge",
                 adj = 0, cex = 0.61, col = cfg$muted)
}

if (sys.nframe() == 0L) render_day06()
