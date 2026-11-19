#!/usr/bin/env Rscript
library(magrittr)
source("posts/2026-11-09-30daymap-09-urban-rural/render-map.R")
if (!"--download" %in% commandArgs(trailingOnly = TRUE)) stop("Opt in with --download")
options(timeout = 180)
cfg <- day09_config()
dir.create(file.path(day09_cache, "routing"), recursive = TRUE, showWarnings = FALSE)
sources <- list()
fetch <- function(name, url, query = NULL) {
  path <- file.path(day09_cache, name)
  if (!file.exists(path)) {
    r <- httr::GET(url, query = query, httr::timeout(90)); httr::stop_for_status(r)
    raw <- httr::content(r, as = "raw")
    x <- jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE)
    if (!is.null(x$error)) stop("Source error for ", name)
    tmp <- paste0(path, ".part"); writeBin(raw, tmp)
    if (!file.rename(tmp, path)) stop("Could not save ", name)
  }
  sources[[name]] <<- list(path = path, url = if (is.null(query)) url else httr::modify_url(url, query = query))
  path
}
read_geo <- function(path) {
  raw <- jsonlite::read_json(path)
  if (!is.null(raw$error) || isTRUE(raw$exceededTransferLimit) || isTRUE(raw$properties$exceededTransferLimit))
    stop("Source response is incomplete: ", path)
  sf::st_read(path, quiet = TRUE) %>% sf::st_transform(cfg$crs) %>% sf::st_make_valid()
}
counties <- fetch("counties.json", "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/1/query",
                  list(where = "STATE='39' AND COUNTY IN ('061','025')", outFields = "*", outSR = 4326,
                       f = "geojson", maxAllowableOffset = 0.0002)) %>% read_geo()
stopifnot(setequal(counties$GEOID, c("39061", "39025")))
region <- sf::st_union(sf::st_geometry(counties))
buffer <- sf::st_buffer(region, cfg$drive_buffer_m)
# This fixed source envelope is checked to contain the complete 25 km study buffer.
source_bbox <- sf::st_as_sfc(sf::st_bbox(c(xmin = -85.15, ymin = 38.50, xmax = -83.45, ymax = 39.75), crs = sf::st_crs(4326))) %>% sf::st_transform(cfg$crs)
stopifnot(lengths(sf::st_covered_by(buffer, source_bbox)) == 1)
retailer_url <- "https://services1.arcgis.com/RLQu0rK7h4kbsBq5/arcgis/rest/services/snap_retailer_location_data/FeatureServer/0/query"
retailer_path <- fetch("grocery-candidates.json", retailer_url,
  list(where = "Store_Type IN ('Supermarket','Super Store','Grocery Store')", geometry = "-85.15,38.50,-83.45,39.75",
       geometryType = "esriGeometryEnvelope", inSR = 4326, returnGeometry = "true", outSR = 4326,
       outFields = "*", f = "geojson"))
all_stores <- read_geo(retailer_path)
if (anyDuplicated(all_stores$Record_ID) || any(sf::st_is_empty(all_stores))) stop("Invalid retailer locations")
keep <- day09_store_eligible(all_stores$Store_Type, all_stores$Store_Name)
nearby <- lengths(sf::st_intersects(all_stores, buffer)) > 0
excluded <- sf::st_drop_geometry(all_stores[!keep | !nearby, c("Record_ID", "Store_Name", "Store_Type")])
excluded$reason <- ifelse(!nearby[!keep | !nearby], "outside 25 km buffer", "type or membership exclusion")
utils::write.csv(excluded, file.path(day09_root, "excluded-retailers.csv"), row.names = FALSE)
stores <- all_stores[keep & nearby, ]
stores <- stores[order(stores$Longitude, stores$Latitude, stores$Record_ID), ]
stores$inside_study <- lengths(sf::st_intersects(stores, region)) > 0
stores$walk_candidate <- lengths(sf::st_intersects(stores, sf::st_buffer(region, cfg$walk_buffer_m))) > 0
stores$lon <- stores$Longitude; stores$lat <- stores$Latitude
# FNS source attributes and returned point geometry must agree before routing.
geo <- sf::st_coordinates(sf::st_transform(stores, 4326))
stopifnot(max(abs(geo[, 1] - stores$lon)) < 1e-5, max(abs(geo[, 2] - stores$lat)) < 1e-5)
utils::write.csv(sf::st_drop_geometry(stores), file.path(day09_root, "stores.csv"), row.names = FALSE, na = "")
fara <- fetch("fara2019-tracts.json", "https://gisportal.ers.usda.gov/server/rest/services/FARA/FARA_2019/MapServer/30/query",
  list(where = "GEOID10 LIKE '39061%' OR GEOID10 LIKE '39025%'",
       outFields = "GEOID10,Cnty_Name,Urban,LowIncomeTracts,LILATracts_Vehicle,HUNVFlag,POP2010,OHU2010,TractHUNV,PovertyRate",
       outSR = 4326, f = "geojson", maxAllowableOffset = 0.0002)) %>% read_geo()
if (anyDuplicated(fara$GEOID10) || !all(fara$LILATracts_Vehicle %in% c(0, 1))) stop("Invalid USDA tract flags")
fara <- suppressWarnings(sf::st_intersection(fara, region))
utils::write.csv(sf::st_drop_geometry(fara), file.path(day09_root, "fara2019-tracts.csv"), row.names = FALSE)
urban <- fetch("urban2020.json", "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Urban/MapServer/0/query",
  list(where = "1=1", geometry = "-84.85,38.75,-83.83,39.45", geometryType = "esriGeometryEnvelope",
       inSR = 4326, outFields = "*", outSR = 4326, f = "geojson", maxAllowableOffset = 0.0002)) %>% read_geo()
urban <- suppressWarnings(sf::st_intersection(urban, region))
# Place names are annotation references, not additional food-access classifications.
dir.create(file.path(day09_cache, "callouts"), showWarnings = FALSE)
label_query <- list(where = "STATE='39' AND COUNTY IN ('061','025')", outFields = "*", f = "geojson", outSR = 4326,
                    geometry = "-84.85,38.75,-83.83,39.45", geometryType = "esriGeometryEnvelope", inSR = 4326,
                    maxAllowableOffset = 0.0002)
label_base <- "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Places_CouSub_ConCity_SubMCD/MapServer"
references <- list(subdivisions = fetch("callouts/subdivisions.json", paste0(label_base, "/1/query"), label_query) %>% read_geo())
label_query$where <- "STATE='39'"
references$places <- fetch("callouts/places.json", paste0(label_base, "/4/query"), label_query) %>% read_geo()
references$neighborhoods <- fetch("callouts/neighborhoods.json",
  "https://cagisonline.hamilton-co.org/arcgis/rest/services/CINC_PLANNING/Cincinnati_Neighborhoods/MapServer/0/query",
  list(where = "1=1", outFields = "*", outSR = 4326, f = "geojson", maxAllowableOffset = 0.0001)) %>% read_geo()
selections <- utils::read.csv(file.path(day09_root, "callout-selections.csv"), colClasses = c(GEOID10 = "character"))
for (i in seq_len(nrow(selections))) {
  tract <- fara[fara$GEOID10 == selections$GEOID10[i], ]
  ref <- references[[selections$reference_layer[i]]]
  field <- if (selections$reference_layer[i] == "neighborhoods") "SNA_NAME" else "NAME"
  ref <- ref[ref[[field]] == selections$reference_name[i], ]
  stopifnot(nrow(tract) == 1, tract$LILATracts_Vehicle == 1, nrow(ref) == 1,
            lengths(sf::st_within(sf::st_point_on_surface(sf::st_geometry(tract)), ref)) == 1)
}
status_path <- fetch("valhalla-status.json", "https://valhalla1.openstreetmap.de/status")
endpoint <- "https://valhalla1.openstreetmap.de/isochrone"
contours <- list(); manifest <- list(); snapped_rows <- list()
for (mode in cfg$modes) {
  indices <- if (mode == "pedestrian") which(stores$walk_candidate) else seq_len(nrow(stores))
  message("Routing ", mode, ": ", length(indices), " destinations")
  for (j in seq_along(indices)) {
    i <- indices[j]; id <- as.character(stores$Record_ID[i]); key <- paste(mode, id, sep = "-")
    request <- day09_request(stores$lon[i], stores$lat[i], mode)
    json <- jsonlite::toJSON(request, auto_unbox = TRUE, digits = 9, pretty = TRUE)
    request_path <- file.path(day09_cache, "routing", paste0(key, "-request.json"))
    response_path <- file.path(day09_cache, "routing", paste0(key, "-response.json"))
    if (file.exists(request_path)) {
      if (!isTRUE(all.equal(jsonlite::read_json(request_path), jsonlite::fromJSON(json, simplifyVector = FALSE))))
        stop("Cached routing request changed: ", key)
    } else writeLines(json, request_path)
    if (!file.exists(response_path)) {
      response <- httr::RETRY("POST", endpoint, body = charToRaw(json), httr::content_type_json(),
        httr::add_headers(`X-Client-Id` = "seanthimons.github.io"), httr::timeout(90), times = 3,
        pause_base = 2, pause_cap = 10, terminate_on = c(400, 401, 403, 404), quiet = TRUE)
      httr::stop_for_status(response)
      payload <- httr::content(response, as = "raw")
      parsed <- jsonlite::fromJSON(rawToChar(payload), simplifyVector = FALSE)
      if (!is.null(parsed$error) || !length(parsed$features)) stop("Invalid routing response: ", key)
      tmp <- paste0(response_path, ".part"); writeBin(payload, tmp)
      if (!file.rename(tmp, response_path)) stop("Could not save route response: ", key)
      # Public demo service: throttle, cache, and never query during rendering.
      Sys.sleep(1.1)
    }
    payload <- jsonlite::read_json(response_path)
    if (!is.null(payload$warnings)) stop("Routing warning requires review: ", key)
    raw <- sf::st_read(response_path, quiet = TRUE) %>% sf::st_transform(cfg$crs)
    polygons <- raw[sf::st_geometry_type(raw) %in% c("POLYGON", "MULTIPOLYGON"), ]
    if (nrow(polygons) != 2 || !setequal(polygons$contour, c(5, 10)) || !all(polygons$metric == "time")) stop("Missing time contour: ", key)
    snap <- raw[!is.na(raw$type) & raw$type == "snapped", ]
    points <- suppressWarnings(sf::st_cast(sf::st_geometry(snap), "POINT"))
    distances <- as.numeric(sf::st_distance(points, stores[i, ]))
    if (!length(distances) || max(distances) > cfg$max_snap_m) stop("Excessive origin snapping: ", key)
    xy <- sf::st_coordinates(sf::st_transform(points, 4326))
    snapped_rows[[key]] <- data.frame(mode = mode, Record_ID = id, lon = xy[,1], lat = xy[,2], snap_m = round(distances, 2))
    contours[[key]] <- sf::st_sf(mode = mode, Record_ID = id, minutes = polygons$contour,
                                geometry = sf::st_make_valid(sf::st_geometry(polygons)))
    manifest[[key]] <- data.frame(mode = mode, Record_ID = id, reverse = TRUE, request = request_path,
      request_sha256 = digest::digest(file = request_path, algo = "sha256"), response = response_path,
      response_sha256 = digest::digest(file = response_path, algo = "sha256"))
    if (j %% 10 == 0 || j == length(indices)) message(mode, " ", j, "/", length(indices))
  }
}
raw_contours <- do.call(rbind, contours)
access <- do.call(rbind, lapply(cfg$modes, function(mode) do.call(rbind, lapply(cfg$minutes, function(minutes) {
  geometry <- sf::st_union(sf::st_geometry(raw_contours[raw_contours$mode == mode & raw_contours$minutes == minutes, ]))
  geometry <- suppressWarnings(sf::st_intersection(geometry, region))
  sf::st_sf(mode = mode, minutes = minutes, geometry = sf::st_make_valid(geometry))
}))))
utils::write.csv(do.call(rbind, manifest), file.path(day09_root, "routing-manifest.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, snapped_rows), file.path(day09_root, "store-snaps.csv"), row.names = FALSE)
path <- file.path(day09_root, "grocery-access.gpkg")
sf::st_write(counties, path, layer = "counties", delete_dsn = TRUE, quiet = TRUE)
sf::st_write(stores, path, layer = "stores", quiet = TRUE)
sf::st_write(access, path, layer = "access", quiet = TRUE)
sf::st_write(urban, path, layer = "urban", quiet = TRUE)
sf::st_write(fara, path, layer = "fara2019", quiet = TRUE)
fingerprint <- function(paths) data.frame(path = paths, sha256 = vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), ""))
paths <- vapply(sources, `[[`, "", "path")
source_manifest <- cbind(url = vapply(sources, `[[`, "", "url"), fingerprint(paths))
source_manifest$retrieved_utc <- format(file.info(paths)$mtime, tz = "UTC", usetz = TRUE)
input_names <- c("grocery-access.gpkg", "stores.csv", "excluded-retailers.csv", "fara2019-tracts.csv", "routing-manifest.csv", "store-snaps.csv", "callout-selections.csv")
jsonlite::write_json(list(sources = source_manifest, render_inputs = fingerprint(file.path(day09_root, input_names)),
  valhalla = jsonlite::read_json(status_path), retrieved_date = format(Sys.Date()),
  counts = list(stores = nrow(stores), inside_study = sum(stores$inside_study), walking_destinations = sum(stores$walk_candidate),
                historical_tracts = nrow(fara), historical_vehicle_lila = sum(fara$LILATracts_Vehicle == 1)),
  note = "Inbound five/ten-minute contours to SNAP supermarkets/superstores; smaller and specialty retailers and membership chains excluded. Stores within 25 km supply driving, within 2 km supply walking. Static road speeds; parking, prices, opening hours and transit not modelled. USDA vehicle-based low-income/low-access tract flags are a 2019 historical benchmark on 2010 tract geometry, not a current designation."),
  file.path(day09_root, "source-snapshot.json"), pretty = TRUE, auto_unbox = TRUE)
message("Day 09 reductions prepared")
