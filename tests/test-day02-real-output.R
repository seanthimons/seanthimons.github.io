# Real cached USGS output checks, not synthetic terrain. Run after render-map.R.
source("posts/2026-11-02-30daymap-02-lines/render-map.R")
check_dependencies()
cfg <- day02_config()
root <- "posts/2026-11-02-30daymap-02-lines/artifacts"
report <- dget(file.path(root, "provenance.R"))
stopifnot(identical(report$config, cfg), report$contour_features > 0,
          all(report$source_bytes > 4e8))
raw <- acquire_tiles("data/30daymap/2026/day02")
stopifnot(identical(unname(tools::md5sum(raw)), report$source_md5))
terrain <- terra::rast(file.path(root, "terrain-20m-utm16.tif"))
smooth <- terra::rast(file.path(root, "smoothed-20m-utm16.tif"))
stopifnot(all(dim(terrain)[1:2] == c(2000, 2000)),
          all(dim(smooth)[1:2] == c(1200, 1200)),
          all(terra::res(terrain) == c(20, 20)),
          all(is.finite(terra::values(terrain))),
          all(is.finite(terra::values(smooth))),
          terra::same.crs(terrain, cfg$crs),
          max(abs(range(terra::values(terrain)) - report$elevation_range_m)) < 1e-5)
geometry <- sf::st_read(file.path(root, "contours-10m.geojson"), quiet = TRUE)
stopifnot(nrow(geometry) == report$contour_features,
          sf::st_crs(geometry)$epsg == 4326,
          all(!sf::st_is_empty(geometry)), all(sf::st_is_valid(geometry)))
geometry <- sf::st_transform(geometry, cfg$crs)
box <- sf::st_bbox(geometry)
extent <- as.vector(terra::ext(smooth))
stopifnot(box[["xmin"]] >= extent[1] - 1,
          box[["xmax"]] <= extent[2] + 1,
          box[["ymin"]] >= extent[3] - 1,
          box[["ymax"]] <= extent[4] + 1)
im <- png::readPNG(file.path(root, "day02-night-survey.png"))
stopifnot(all(dim(im)[1:2] == c(2000,2000)),
          max(abs(im[1,1,1:3] - as.numeric(col2rgb(cfg$background))/255)) < 1/255,
          max(im) > min(im))
cat("PASS: real USGS fingerprints, full finite terrain coverage, CRS/resolution/crop, contour geometry and PNG palette/dimensions\n")
