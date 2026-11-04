# Dependency-free unit checks. Run from the repository root.
script <- file.path("posts", "2026-11-02-30daymap-02-lines", "render-map.R")
stopifnot(file.exists(script))
source(script)
cfg <- day02_config()
stopifnot(identical(cfg$center, c(-84.505, 39.085)), cfg$span_m == 24000,
          cfg$resolution_m == 20, cfg$sigma_m == 20, cfg$crs == "EPSG:26916",
          cfg$background == "#18282D", cfg$ink == "#D3CDBB",
          identical(cfg$levels, seq(100, 350, 10)))
w <- gaussian_kernel(cfg$sigma_m / cfg$resolution_m)
stopifnot(all(dim(w) == c(9L, 9L)), abs(sum(w) - 1) < 1e-12,
          identical(w, t(w)), w[5, 5] == max(w),
          isTRUE(all.equal(w, w[9:1, 9:1])))
stopifnot(inherits(try(gaussian_kernel(0), silent = TRUE), "try-error"))
u <- tile_urls()
stopifnot(length(u) == 2, all(grepl("^https://prd-tnm.s3.amazonaws.com/", u)),
          identical(basename(u), c("USGS_13_n40w085.tif", "USGS_13_n39w085.tif")))
# Exercise acquisition's cache-only path with temporary signature fixtures.
# These bytes are test fixtures, never elevation inputs or published data.
local({
  cache <- tempfile("day02-cache-")
  dir.create(cache)
  on.exit(unlink(cache, recursive = TRUE))
  missing <- try(acquire_tiles(cache), silent = TRUE)
  stopifnot(inherits(missing, "try-error"), grepl("Missing raw USGS tile", missing))
  for (name in basename(u)) writeBin(as.raw(c(73, 73, 42, 0)), file.path(cache, name))
  stopifnot(identical(basename(acquire_tiles(cache)), basename(u)))
  writeBin(charToRaw("<html>error</html>"), file.path(cache, basename(u)[1]))
  stopifnot(inherits(try(acquire_tiles(cache), silent = TRUE), "try-error"))
})
stopifnot(inherits(try(day02_main("--bogus"), silent = TRUE), "try-error"),
          inherits(try(day02_main("--cache-dir"), silent = TRUE), "try-error"))
cat("PASS: Day02 configuration, Gaussian kernel, raw source URLs, cache validation, CLI errors\n")
if (all(vapply(c("terra", "sf"), requireNamespace, logical(1), quietly = TRUE))) {
  # A constant surface must remain constant away from its padded edges.
  r <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 400,
                   ymin = 0, ymax = 400, crs = cfg$crs)
  terra::values(r) <- 123
  s <- terra::focal(r, w = w, fun = "sum", na.policy = "all", fillvalue = NA)
  stopifnot(max(abs(terra::values(terra::crop(s, terra::ext(100, 300, 100, 300)))) - 123) < 1e-9)
  cat("PASS: terra Gaussian constant-surface check\n")
} else {
  cat("SKIP: spatial integration checks require terra and sf; no terrain render verified\n")
}
