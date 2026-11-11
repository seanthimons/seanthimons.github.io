#!/usr/bin/env Rscript
# Explicit network step. The published post and renderer never contact a routing API.
library(magrittr)
source("posts/2026-11-07-30daymap-07-10-minute-map/render-map.R")
if (!"--download" %in% commandArgs(trailingOnly = TRUE)) stop("Opt in with --download")
options(timeout = 180)
cfg <- day07_config()
dir.create(day07_cache, recursive = TRUE, showWarnings = FALSE)
endpoint <- "https://valhalla1.openstreetmap.de/isochrone"
requests <- day07_requests()
urls <- c(`origin.osm` = "https://api.openstreetmap.org/api/0.6/map?bbox=-84.514,39.1008,-84.5118,39.1025",
          `valhalla-status.json` = "https://valhalla1.openstreetmap.de/status")
fetch <- function(url, path) {
  if (!file.exists(path)) {
    tmp <- paste0(path, ".part")
    utils::download.file(url, tmp, mode = "wb", method = "libcurl", quiet = TRUE)
    if (file.size(tmp) < 100 || !file.rename(tmp, path)) stop("Invalid download: ", url)
  }
}
for (i in seq_along(urls)) fetch(urls[i], file.path(day07_cache, names(urls)[i]))
origin_doc <- xml2::read_xml(file.path(day07_cache, "origin.osm"))
origin_node <- xml2::xml_find_first(origin_doc, "/osm/node[@id='13840947952']")
if (is.na(xml2::xml_name(origin_node)) ||
    max(abs(as.numeric(xml2::xml_attrs(origin_node)[c("lon", "lat")]) - cfg$origin)) > 1e-7)
  stop("Fountain Square OSM location changed; review the origin")
origin <- sf::st_as_sf(data.frame(lon = cfg$origin[1], lat = cfg$origin[2]), coords = c("lon", "lat"), crs = 4326) %>%
  sf::st_transform(cfg$crs)
contours <- list(); snaps <- list()
for (mode in cfg$modes) {
  req_path <- file.path(day07_cache, paste0(mode, "-request.json"))
  json <- jsonlite::toJSON(requests[[mode]], auto_unbox = TRUE, pretty = TRUE, digits = 9)
  if (file.exists(req_path)) {
    old <- jsonlite::fromJSON(req_path, simplifyVector = FALSE)
    new <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    if (!isTRUE(all.equal(old, new))) stop("Cached request differs for ", mode, "; remove its request and response together after review")
  } else writeLines(json, req_path)
  response_path <- file.path(day07_cache, paste0(mode, "-response.json"))
  if (!file.exists(response_path)) {
    r <- httr::POST(endpoint, body = charToRaw(json), httr::content_type_json(),
                     httr::add_headers(`X-Client-Id` = "seanthimons.github.io"), httr::timeout(60))
    httr::stop_for_status(r)
    payload <- httr::content(r, as = "raw")
    parsed <- jsonlite::fromJSON(rawToChar(payload), simplifyVector = FALSE)
    if (!is.null(parsed$error) || length(parsed$features) < 2) stop("Invalid routing response for ", mode)
    writeBin(payload, response_path)
  }
  response <- jsonlite::read_json(response_path)
  if (!is.null(response$warnings)) stop("Routing service warning; review before accepting: ", jsonlite::toJSON(response$warnings))
  raw <- sf::st_read(response_path, quiet = TRUE)
  polygons <- raw[sf::st_geometry_type(raw) %in% c("POLYGON", "MULTIPOLYGON"), ]
  if (nrow(polygons) != 2 || !setequal(polygons$contour, c(5, 10)) || !all(polygons$metric == "time"))
    stop("Missing time contours for ", mode)
  contours[[mode]] <- sf::st_sf(mode = mode, minutes = polygons$contour,
                               geometry = sf::st_make_valid(sf::st_geometry(polygons)))
  snapped <- raw[!is.na(raw$type) & raw$type == "snapped", ]
  points <- suppressWarnings(sf::st_cast(sf::st_geometry(snapped), "POINT"))
  xy <- sf::st_coordinates(points)
  d <- as.numeric(sf::st_distance(sf::st_transform(points, cfg$crs), origin))
  if (!length(d) || max(d) > 100) stop("Excessive origin snapping for ", mode)
  snaps[[mode]] <- data.frame(mode = mode, lon = xy[, 1], lat = xy[, 2], distance_m = round(d, 2))
  urls[paste0(mode, "-response.json")] <- endpoint
}
contours <- do.call(rbind, contours)
sf::st_write(contours, file.path(day07_root, "isochrones.geojson"), delete_dsn = TRUE, quiet = TRUE)
utils::write.csv(do.call(rbind, snaps), file.path(day07_root, "origin-snaps.csv"), row.names = FALSE)
utils::write.csv(data.frame(name = "Fountain Square", lon = cfg$origin[1], lat = cfg$origin[2],
                            osm_url = "https://www.openstreetmap.org/node/13840947952"),
                 file.path(day07_root, "origin.csv"), row.names = FALSE)
jsonlite::write_json(requests, file.path(day07_root, "routing-requests.json"), auto_unbox = TRUE, pretty = TRUE, digits = 9)
# Census roads and river polygons provide context; Valhalla's OSM graph provides the routing.
base <- "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/"
layers <- c(primary = "Transportation/MapServer/2", secondary = "Transportation/MapServer/6", water = "Hydro/MapServer/1")
roi <- sf::st_as_sfc(sf::st_bbox(c(xmin = cfg$bounds[1], ymin = cfg$bounds[2], xmax = cfg$bounds[3], ymax = cfg$bounds[4]), crs = sf::st_crs(4326))) %>%
  sf::st_transform(cfg$crs)
context <- lapply(names(layers), function(key) {
  query <- list(where = "1=1", geometry = paste(cfg$bounds, collapse = ","), geometryType = "esriGeometryEnvelope",
                inSR = 4326, spatialRel = "esriSpatialRelIntersects", outFields = "*", returnGeometry = "true",
                outSR = 4326, geometryPrecision = 5, maxAllowableOffset = 0.00005, f = "geojson")
  url <- httr::modify_url(paste0(base, layers[[key]], "/query"), query = query)
  filename <- paste0(key, ".json"); path <- file.path(day07_cache, filename)
  fetch(url, path)
  raw <- jsonlite::read_json(path)
  if (!is.null(raw$error) || isTRUE(raw$exceededTransferLimit) || isTRUE(raw$properties$exceededTransferLimit)) stop("Incomplete Census response: ", key)
  x <- sf::st_read(path, quiet = TRUE) %>% sf::st_transform(cfg$crs) %>% sf::st_make_valid()
  x <- suppressWarnings(sf::st_intersection(x, roi))
  urls[filename] <<- url
  sf::st_sf(kind = key, name = if ("NAME" %in% names(x)) x$NAME else "", geometry = sf::st_geometry(x))
})
roads <- rbind(context[[1]], context[[2]]) %>% sf::st_simplify(dTolerance = 10) %>% sf::st_transform(4326)
water <- context[[3]] %>% sf::st_simplify(dTolerance = 5, preserveTopology = TRUE) %>% sf::st_transform(4326)
sf::st_write(roads, file.path(day07_root, "roads.geojson"), delete_dsn = TRUE, quiet = TRUE)
sf::st_write(water, file.path(day07_root, "water.geojson"), delete_dsn = TRUE, quiet = TRUE)
origin_xy <- sf::st_coordinates(origin)[1, ]
projected <- sf::st_transform(contours, cfg$crs)
summary <- do.call(rbind, lapply(cfg$modes, function(mode) {
  g <- projected[projected$mode == mode & projected$minutes == 10, ]
  data.frame(mode = mode, minutes = 10, max_straight_line_km = round(day07_radius(sf::st_geometry(g), origin_xy), 3))
}))
utils::write.csv(summary, file.path(day07_root, "summary.csv"), row.names = FALSE)
fingerprint <- function(paths) data.frame(path = paths, sha256 = vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), ""))
input_names <- c("isochrones.geojson", "roads.geojson", "water.geojson", "origin.csv", "origin-snaps.csv", "routing-requests.json", "summary.csv")
status <- jsonlite::read_json(file.path(day07_cache, "valhalla-status.json"), simplifyVector = TRUE)
sources <- cbind(url = unname(urls), fingerprint(file.path(day07_cache, names(urls))))
sources$retrieved_utc <- format(file.info(sources$path)$mtime, tz = "UTC", usetz = TRUE)
jsonlite::write_json(list(sources = sources, render_inputs = fingerprint(file.path(day07_root, input_names)),
                         valhalla = status, retrieved_date = format(Sys.Date()),
                         note = "Outward time contours; speed_types=[] excludes traffic speed sources. Other costing defaults are server-version dependent. Census context is separate from OSM routing. Generalized contours are envelopes, not a guarantee that every interior point is accessible."),
                     file.path(day07_root, "source-snapshot.json"), pretty = TRUE, auto_unbox = TRUE)
message("Day 07 acquisition complete")
