#!/usr/bin/env Rscript
# All acquisition and terrain processing here are native R. Source safely for tests.
# Run from the repository root; prefer its ignored, project-local package library.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day02_config <- function() {
  list(center = c(-84.505, 39.085), span_m = 24000, buffer_span_m = 40000,
       resolution_m = 20, sigma_m = 20, crs = "EPSG:26916",
       levels = seq(100, 350, 10), background = "#18282D", ink = "#D3CDBB")
}

gaussian_kernel <- function(sigma_cells) {
  stopifnot(length(sigma_cells) == 1L, is.finite(sigma_cells), sigma_cells > 0)
  radius <- ceiling(4 * sigma_cells)
  offsets <- seq.int(-radius, radius)
  w <- outer(offsets, offsets, function(x, y) exp(-(x^2 + y^2) / (2 * sigma_cells^2)))
  w / sum(w)
}

tile_urls <- function() {
  tiles <- c("n40w085", "n39w085")
  paste0("https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/current/",
         tiles, "/USGS_13_", tiles, ".tif")
}

check_dependencies <- function() {
  needed <- c("terra", "sf")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing required R packages: ", paste(missing, collapse = ", "),
    ". Load the project-local GIS runtime with `sh scripts/map-r.sh`, or run the explicit setup recipe. Rendering never installs packages automatically.", call. = FALSE)
}

# A signature check prevents treating an HTTP error page as a cached elevation tile.
check_tiff <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  signature <- readBin(con, "raw", n = 4)
  valid <- list(as.raw(c(73, 73, 42, 0)), as.raw(c(77, 77, 0, 42)),
                as.raw(c(73, 73, 43, 0)), as.raw(c(77, 77, 0, 43)))
  if (!any(vapply(valid, identical, logical(1), signature)))
    stop("Not a TIFF: ", path, call. = FALSE)
  invisible(TRUE)
}

acquire_tiles <- function(cache_dir, download = FALSE) {
  urls <- tile_urls()
  paths <- file.path(cache_dir, basename(urls))
  for (i in seq_along(paths)) {
    if (!file.exists(paths[i])) {
      if (!download) stop("Missing raw USGS tile: ", paths[i],
        ". Populate the shared cache or use --download.", call. = FALSE)
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      tmp <- paste0(paths[i], ".part")
      tryCatch({
        old <- options(timeout = max(600, getOption("timeout")))
        on.exit(options(old), add = TRUE)
        status <- utils::download.file(urls[i], tmp, mode = "wb", method = "libcurl")
        if (status != 0) stop("USGS download failed: ", urls[i])
        check_tiff(tmp)
        if (!file.rename(tmp, paths[i])) stop("Could not finalize tile: ", paths[i])
      }, finally = { if (file.exists(tmp)) unlink(tmp) })
    }
    check_tiff(paths[i])
  }
  paths
}

render_day02 <- function(cache_dir, output_dir, download = FALSE) {
  # Fail before downloading large files or creating artifacts if packages are absent.
  check_dependencies()
  cfg <- day02_config()
  paths <- acquire_tiles(cache_dir, download)
  center <- terra::vect(matrix(cfg$center, ncol = 2), crs = "EPSG:4326")
  xy <- terra::crds(terra::project(center, cfg$crs))[1, ]
  square <- function(span) terra::ext(xy[1] - span / 2, xy[1] + span / 2,
                                      xy[2] - span / 2, xy[2] + span / 2)
  target <- terra::rast(square(cfg$buffer_span_m), resolution = cfg$resolution_m,
                        crs = cfg$crs)
  # The original geographic crop covers the 40 km processing grid with margin.
  # Crop before mosaicking to avoid materializing the complete one-degree tiles.
  sources <- lapply(paths, terra::rast)
  if (!terra::compareGeom(sources[[1]], sources[[2]], ext = FALSE,
                           rowcol = FALSE, stopOnError = FALSE))
    stop("USGS tile grids or CRS do not agree.")
  bounds <- terra::as.polygons(terra::ext(-84.78, -84.23, 38.86, 39.34),
                               crs = "EPSG:4326")
  bounds <- terra::project(bounds, terra::crs(sources[[1]]))
  pieces <- lapply(sources, function(r) terra::crop(r, terra::ext(bounds), snap = "out"))
  dem <- terra::mosaic(pieces[[1]], pieces[[2]], fun = "mean")
  terrain <- terra::project(dem, target, method = "bilinear")
  limits <- range(terra::values(terrain), na.rm = TRUE)
  if (any(!is.finite(terra::values(terrain)))) stop("Missing terrain in buffered extent.")
  if (!(limits[1] > 50 && limits[1] < 200 && limits[2] > 250 && limits[2] < 500))
    stop("Implausible Cincinnati elevation range: ", paste(limits, collapse = ", "))
  w <- gaussian_kernel(cfg$sigma_m / cfg$resolution_m)
  smooth <- terra::focal(terrain, w = w, fun = "sum", na.policy = "all", fillvalue = NA)
  # Crop well inside the 40 km buffer so Gaussian edge padding cannot enter the map.
  display <- terra::crop(smooth, square(cfg$span_m), snap = "near")
  if (any(!is.finite(terra::values(display)))) stop("Missing smoothed terrain in map extent.")
  lines <- terra::as.contour(display, levels = cfg$levels, maxcells = terra::ncell(display))
  contours <- sf::st_as_sf(lines)
  if (!nrow(contours) || any(sf::st_is_empty(contours))) stop("No valid contours generated.")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  terra::writeRaster(terrain, file.path(output_dir, "terrain-20m-utm16.tif"),
                     overwrite = TRUE, gdal = "COMPRESS=DEFLATE")
  terra::writeRaster(display, file.path(output_dir, "smoothed-20m-utm16.tif"),
                     overwrite = TRUE, gdal = "COMPRESS=DEFLATE")
  sf::st_write(sf::st_transform(contours, 4326),
               file.path(output_dir, "contours-10m.geojson"), delete_dsn = TRUE, quiet = TRUE)
  draw <- function() {
    graphics::par(mar = rep(0, 4), bg = cfg$background, xaxs = "i", yaxs = "i")
    e <- as.vector(square(cfg$span_m))
    # asp=1 preserves metric geometry. A 2.5% border matches the approved study.
    graphics::par(plt = c(.025, .975, .025, .975))
    graphics::plot(sf::st_geometry(contours), col = cfg$ink, lwd = 0.44,
                   xlim = e[1:2], ylim = e[3:4], asp = 1, axes = FALSE,
                   xaxs = "i", yaxs = "i")
  }
  save_plot <- function(open_device) {
    open_device()
    on.exit(grDevices::dev.off())
    draw()
  }
  save_plot(function() grDevices::png(file.path(output_dir, "day02-night-survey.png"),
    width = 2000, height = 2000, res = 250, bg = cfg$background))
  save_plot(function() grDevices::svg(file.path(output_dir, "day02-night-survey.svg"),
    width = 8, height = 8, bg = cfg$background))
  save_plot(function() grDevices::pdf(file.path(output_dir, "day02-night-survey.pdf"),
    width = 8, height = 8, bg = cfg$background, timestamp = FALSE))
  report <- list(config = cfg, source_urls = tile_urls(),
    source_paths = normalizePath(paths), source_bytes = file.info(paths)$size,
    source_md5 = unname(tools::md5sum(paths)),
    note = "MD5 identifies local raw inputs; it is not an upstream integrity assertion. USGS current URLs are mutable.",
    elevation_range_m = limits, contour_features = nrow(contours),
    resampling = "bilinear", smoothing = "normalized 9x9 Gaussian, sigma 20 m, radius 80 m",
    water_mask = "none", session = utils::capture.output(sessionInfo()))
  writeLines(sub("[[:blank:]]+$", "", utils::capture.output(dput(report))),
             con = file.path(output_dir, "provenance.R"))
  message("Native R terrain rendered: ", normalizePath(output_dir))
  invisible(report)
}

day02_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste("Usage: Rscript posts/2026-11-02-30daymap-02-lines/render-map.R",
    "[--download] [--cache-dir PATH] [--output-dir PATH]",
    "Run from the repository root. No packages are installed automatically.",
    "Default cache: data/30daymap/2026/day02 (raw USGS tiles only).",
    "Default output: posts/2026-11-02-30daymap-02-lines/artifacts",
    "--download permits native R download.file acquisition of missing raw tiles.",
    "Without --download, existing tiles are required. --help needs only base R.", sep = "\n")
  if (any(args %in% c("--help", "-h"))) { cat(usage, "\n"); return(invisible(NULL)) }
  cache <- "data/30daymap/2026/day02"
  output <- "posts/2026-11-02-30daymap-02-lines/artifacts"
  download <- FALSE
  i <- 1L
  while (i <= length(args)) {
    arg <- args[i]
    if (arg == "--download") download <- TRUE
    else if (arg %in% c("--cache-dir", "--output-dir")) {
      if (i == length(args) || startsWith(args[i + 1L], "--")) stop("Missing value for ", arg)
      i <- i + 1L
      if (arg == "--cache-dir") cache <- args[i] else output <- args[i]
    } else stop("Unknown argument: ", arg, "\n", usage, call. = FALSE)
    i <- i + 1L
  }
  render_day02(cache, output, download)
}

if (sys.nframe() == 0L) day02_main()
