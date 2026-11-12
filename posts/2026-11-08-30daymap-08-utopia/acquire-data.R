#!/usr/bin/env Rscript
# Explicit network step; ATTAINS credentials travel only in the X-Api-Key header.
library(magrittr)
source("posts/2026-11-08-30daymap-08-utopia/render-map.R")
if (!"--download" %in% commandArgs(trailingOnly = TRUE)) stop("Opt in with --download")
options(timeout = 180)
cfg <- day08_config()
dir.create(file.path(day08_cache, "freshwater"), recursive = TRUE, showWarnings = FALSE)
sources <- list()
fetch <- function(filename, url, params = NULL, attains = FALSE, post = FALSE) {
  path <- file.path(day08_cache, filename)
  safe_url <- if (is.null(params) || post) url else httr::modify_url(url, query = params)
  if (!file.exists(path)) {
    headers <- if (attains) {
      key <- Sys.getenv("ATTAINS_API_KEY")
      if (!nzchar(key)) stop("Export ATTAINS_API_KEY to acquire uncached assessment data")
      httr::add_headers(`X-Api-Key` = key)
    } else httr::add_headers(`User-Agent` = "seanthimons-map-challenge/1.0")
    response <- if (post) httr::POST(url, body = params, encode = "form", headers, httr::timeout(120)) else
      httr::GET(url, query = params, headers, httr::timeout(120))
    httr::stop_for_status(response)
    raw <- httr::content(response, as = "raw")
    parsed <- jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE)
    if (!is.null(parsed$error)) stop("Upstream returned an error for ", filename)
    tmp <- paste0(path, ".part"); writeBin(raw, tmp)
    if (!file.rename(tmp, path)) stop("Could not save ", filename)
  }
  sources[[filename]] <<- list(path = path, url = safe_url,
    reproduction_method = if (post) "POST" else "GET",
    reproduction_body = if (post) as.character(jsonlite::toJSON(params, auto_unbox = TRUE)) else "")
  path
}
units_path <- fetch("ohio-units.json", "https://api.epa.gov/attains/assessmentUnits", list(stateCode = "OH"), TRUE)
report_path <- fetch("assessments-2024.json", "https://api.epa.gov/attains/assessments",
                      list(organizationId = cfg$organization, reportingCycle = cfg$cycle), TRUE)
units <- jsonlite::read_json(units_path)
reports <- jsonlite::read_json(report_path)
if (length(reports$items) != 1L || reports$items[[1]]$organizationIdentifier != cfg$organization ||
    reports$items[[1]]$reportingCycleText != cfg$cycle || reports$items[[1]]$reportStatusCode != "EPA Final Action" ||
    length(reports$items[[1]]$assessments) != reports$count) stop("Unexpected assessment report or incomplete response")
unit_list <- unlist(lapply(units$items, `[[`, "assessmentUnits"), recursive = FALSE)
if (length(unit_list) != units$count) stop("Incomplete assessment-unit inventory")
unit_ids <- vapply(unit_list, `[[`, "", "assessmentUnitIdentifier")
if (anyDuplicated(unit_ids)) stop("Ambiguous organization/unit identifiers")
report <- reports$items[[1]]
rows <- list(); uses <- list(); exclusions <- list()
for (assessment in report$assessments) {
  id <- assessment$assessmentUnitIdentifier
  ix <- match(id, unit_ids)
  if (is.na(ix)) stop("Assessment unit has no authoritative unit record: ", id)
  unit <- unit_list[[ix]]
  types <- vapply(unit$waterTypes, `[[`, "", "waterTypeCode")
  if (!identical(types, "WATERSHED")) {
    exclusions[[length(exclusions) + 1L]] <- data.frame(assessment_unit_id = id, type = paste(types, collapse = ";"))
    next
  }
  aquatic <- Filter(function(u) startsWith(u$useName, "Aquatic Life"), assessment$useAttainments)
  codes <- vapply(aquatic, `[[`, "", "useAttainmentCode")
  hucs <- Filter(function(l) l$locationTypeCode == "HUC-12", unit$locations)
  if (length(hucs) != 1) stop("No unique HUC12 link: ", id)
  rows[[length(rows) + 1L]] <- data.frame(
    organization_id = cfg$organization, assessment_unit_id = id, name = unit$assessmentUnitName,
    huc12 = hucs[[1]]$locationText, reporting_cycle = cfg$cycle, report_status = report$reportStatusCode,
    status = day08_status(codes), aquatic_use_count = length(codes), attainment_codes = paste(sort(unique(codes)), collapse = ";"))
  for (u in aquatic) {
    monitoring <- u$assessmentMetadata$monitoringActivity
    uses[[length(uses) + 1L]] <- data.frame(assessment_unit_id = id, use_name = u$useName,
      code = u$useAttainmentCode, threatened = u$threatenedIndicator,
      monitoring_start = if (is.null(monitoring$monitoringStartDate)) "" else monitoring$monitoringStartDate,
      monitoring_end = if (is.null(monitoring$monitoringEndDate)) "" else monitoring$monitoringEndDate)
  }
}
records <- do.call(rbind, rows)
records <- records[order(records$assessment_unit_id), ]
stopifnot(!anyDuplicated(records$assessment_unit_id), !anyDuplicated(records$huc12))
utils::write.csv(records, file.path(day08_root, "assessments.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, uses), file.path(day08_root, "aquatic-uses.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, exclusions), file.path(day08_root, "excluded-units.csv"), row.names = FALSE)

outline_path <- fetch("ohio-outline.json",
  "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/0/query",
  list(where = "STATE='39'", outFields = "*", outSR = 4326, f = "geojson", maxAllowableOffset = 0.001))
huc_path <- fetch("ohio-huc12.json", "https://hydro.nationalmap.gov/arcgis/rest/services/wbd/MapServer/6/query",
  list(where = "states LIKE '%OH%'", outFields = "huc12,name,states", outSR = 4326,
       f = "geojson", maxAllowableOffset = 0.0005, resultRecordCount = 3000))
huc_response <- jsonlite::read_json(huc_path)
if (isTRUE(huc_response$exceededTransferLimit) || isTRUE(huc_response$properties$exceededTransferLimit)) stop("Truncated WBD geometry")
ohio <- sf::st_read(outline_path, quiet = TRUE) %>% sf::st_transform(cfg$crs) %>% sf::st_make_valid()
stopifnot(nrow(ohio) == 1, ohio$STATE == "39")
huc <- sf::st_read(huc_path, quiet = TRUE) %>% sf::st_transform(cfg$crs) %>% sf::st_make_valid()
if (anyDuplicated(huc$huc12)) stop("Duplicate HUC12 geometries")
match_index <- match(records$huc12, huc$huc12)
if (anyNA(match_index)) stop("No geometry for HUC12: ", paste(records$huc12[is.na(match_index)], collapse = ", "))
watersheds <- sf::st_sf(records, geometry = sf::st_geometry(huc)[match_index])
watersheds <- suppressWarnings(sf::st_intersection(watersheds, sf::st_geometry(ohio)))
watersheds <- watersheds[match(records$assessment_unit_id, watersheds$assessment_unit_id), ]
if (any(sf::st_is_empty(watersheds)) || anyNA(watersheds$assessment_unit_id)) stop("Watershed disappeared after clipping to Ohio")
watersheds <- sf::st_simplify(watersheds, dTolerance = 60, preserveTopology = TRUE)

freshwater <- "https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/PredECHydroline/FeatureServer/0/query"
selection <- list(f = "json", where = "StreamName IS NOT NULL AND StreamName <> ''",
                  geometry = paste(cfg$bounds[c(1, 2, 3, 4)], collapse = ","),
                  geometryType = "esriGeometryEnvelope", inSR = 4326, spatialRel = "esriSpatialRelIntersects")
ids_path <- fetch("freshwater-named-ids.json", freshwater, c(selection, list(returnIdsOnly = "true")))
ids <- sort(unlist(jsonlite::read_json(ids_path)$objectIds))
if (!length(ids) || anyDuplicated(ids)) stop("Invalid Freshwater reach inventory")
chunks <- split(ids, ceiling(seq_along(ids) / 1000))
streams <- vector("list", length(chunks))
page_counts <- list()
for (i in seq_along(chunks)) {
  expected <- chunks[[i]]
  query <- list(f = "geojson", objectIds = paste(expected, collapse = ","),
                outFields = "OBJECTID,COMID,StreamName,AvgPredEC,FTYPE,FCODE", outSR = 4326,
                returnGeometry = "true", maxAllowableOffset = 0.0003, geometryPrecision = 5, resultRecordCount = 1000)
  path <- fetch(sprintf("freshwater/page-%03d.json", i - 1L), freshwater, query, post = TRUE)
  page <- jsonlite::read_json(path)
  actual <- vapply(page$features, function(f) f$properties$OBJECTID, numeric(1))
  # The complete ID inventory, not page size, establishes completeness at the service cap.
  if (anyDuplicated(actual) || !setequal(actual, expected)) stop("Missing or extra Freshwater reach IDs on page ", i)
  page_counts[[i]] <- data.frame(page = i - 1L, requested_ids = length(expected), returned_ids = length(actual),
    transfer_limit_flag = isTRUE(page$properties$exceededTransferLimit), all_requested_ids_returned = TRUE)
  x <- sf::st_read(path, quiet = TRUE)
  streams[[i]] <- x[c("OBJECTID", "COMID", "StreamName")]
}
streams <- do.call(rbind, streams)
if (nrow(streams) != length(ids) || anyDuplicated(streams$OBJECTID)) stop("Incomplete Freshwater collection")
streams <- streams %>% sf::st_transform(cfg$crs) %>% sf::st_make_valid()
streams <- suppressWarnings(sf::st_intersection(streams, sf::st_geometry(ohio))) %>%
  sf::st_simplify(dTolerance = 80, preserveTopology = TRUE)
if (any(sf::st_is_empty(streams))) stop("Empty stream geometry after reduction")
utils::write.csv(do.call(rbind, page_counts), file.path(day08_root, "freshwater-pages.csv"), row.names = FALSE)

path <- file.path(day08_root, "ohio-map.gpkg")
sf::st_write(watersheds, path, layer = "watersheds", delete_dsn = TRUE, quiet = TRUE)
sf::st_write(streams, path, layer = "streams", quiet = TRUE)
sf::st_write(ohio, path, layer = "ohio", quiet = TRUE)
counts <- table(factor(records$status, levels = names(cfg$colors)))
summary <- data.frame(status = names(counts), units = as.integer(counts), percent_all_units = round(100 * as.integer(counts) / nrow(records), 3))
utils::write.csv(summary, file.path(day08_root, "summary.csv"), row.names = FALSE)
fingerprint <- function(paths) data.frame(path = paths, sha256 = vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), ""))
source_paths <- vapply(sources, `[[`, "", "path")
manifest <- cbind(url = vapply(sources, `[[`, "", "url"), fingerprint(source_paths))
manifest$reproduction_method <- vapply(sources, `[[`, "", "reproduction_method")
manifest$reproduction_body <- vapply(sources, `[[`, "", "reproduction_body")
manifest$retrieved_utc <- format(file.info(source_paths)$mtime, tz = "UTC", usetz = TRUE)
dates <- sort(unique(format(file.info(source_paths)$mtime, "%d %b %Y", tz = "UTC")))
inputs <- file.path(day08_root, c("assessments.csv", "aquatic-uses.csv", "excluded-units.csv", "freshwater-pages.csv", "ohio-map.gpkg", "summary.csv"))
jsonlite::write_json(list(sources = manifest, render_inputs = fingerprint(inputs), organization = cfg$organization,
                         reporting_cycle = cfg$cycle, report_status = report$reportStatusCode, retrieval_dates = paste(dates, collapse = " / "),
                         coverage = list(report_assessments = reports$count, mapped_watershed_units = nrow(records),
                                         excluded_units = length(exclusions), wbd_units_returned = nrow(huc),
                                         freshwater_named_ids_bbox = length(ids), freshwater_features_in_ohio = nrow(streams)),
                         note = "Watershed reporting status is not individual-reach condition. Freshwater Explorer contributes named-stream geometry only; predicted background conductivity is not used to classify attainment. The full-support goal is stated in text; the map shows reported 2024 watershed status."),
                     file.path(day08_root, "source-snapshot.json"), pretty = TRUE, auto_unbox = TRUE)
message("Day 08 reductions prepared")
