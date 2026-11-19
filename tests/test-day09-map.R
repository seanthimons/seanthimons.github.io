# Run from the repository root with sh scripts/map-r.sh.
source("posts/2026-11-09-30daymap-09-urban-rural/render-map.R")
cfg <- day09_config()
# Retailer selection excludes convenience/specialty formats and the declared membership chains.
stopifnot(identical(day09_store_eligible(c("Supermarket", "Super Store", "Grocery Store", "Convenience Store", "Super Store", "Super Store"),
                                       c("ALDI", "Kroger", "Local Grocery", "Fuel Stop", "Costco Wholesale", "Sam's Club")),
                    c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE)))
for (mode in cfg$modes) {
  request <- day09_request(-84.5, 39.1, mode)
  stopifnot(request$reverse, request$polygons, request$show_locations, request$denoise == 0,
            request$costing == mode, identical(vapply(request$contours, `[[`, numeric(1), "time"), c(5, 10)),
            request$locations[[1]]$lon == -84.5, request$locations[[1]]$lat == 39.1)
}
stopifnot(day09_request(-84.5, 39.1, "pedestrian")$costing_options$pedestrian$walking_speed == 5.1,
          length(day09_request(-84.5, 39.1, "auto")$costing_options$auto$speed_types) == 0,
          day09_request(-84.5, 39.1, "auto")$costing_options$auto$top_speed == 140,
          inherits(try(day09_request(NA, 39.1, "auto"), silent = TRUE), "try-error"),
          inherits(try(day09_request(-84.5, 39.1, "bicycle"), silent = TRUE), "try-error"))
snapshot <- verify_day09(); data <- read_day09()
stopifnot(nrow(data$stores) == 195, sum(data$stores$inside_study) == 90, sum(data$stores$walk_candidate) == 103,
          nrow(data$tracts) == 262, sum(data$tracts$LILATracts_Vehicle == 1) == 63,
          all(data$tracts$LowIncomeTracts[data$tracts$LILATracts_Vehicle == 1] == 1),
          all(sf::st_is_valid(data$urban)), all(sf::st_is_valid(data$tracts)),
          sf::st_crs(data$access)$epsg == cfg$crs)
# Each numbered annotation identifies one flagged tract, with its anchor inside that tract.
indices <- match(data$callouts$GEOID10, data$tracts$GEOID10)
stopifnot(nrow(data$callouts) == 7, !anyNA(indices), !anyDuplicated(data$callouts$GEOID10),
          identical(data$callouts$number, 1:7), all(data$tracts$LILATracts_Vehicle[indices] == 1),
          all(diag(sf::st_within(data$callouts, data$tracts[indices, ], sparse = FALSE))),
          all(is.finite(data$callouts$dx_m)), all(is.finite(data$callouts$dy_m)))
# Every eligible store/mode pair is represented once; a service cap must not silently remove destinations.
manifest <- utils::read.csv(file.path(day09_root, "routing-manifest.csv"), colClasses = "character")
stopifnot(!anyDuplicated(paste(manifest$mode, manifest$Record_ID)), all(manifest$reverse == "TRUE"),
          all(grepl("^[a-f0-9]{64}$", manifest$request_sha256)), all(grepl("^[a-f0-9]{64}$", manifest$response_sha256)),
          setequal(manifest$Record_ID[manifest$mode == "auto"], as.character(data$stores$Record_ID)),
          setequal(manifest$Record_ID[manifest$mode == "pedestrian"], as.character(data$stores$Record_ID[data$stores$walk_candidate])),
          sum(manifest$mode == "auto") == nrow(data$stores),
          sum(manifest$mode == "pedestrian") == sum(data$stores$walk_candidate))
snaps <- utils::read.csv(file.path(day09_root, "store-snaps.csv"))
stopifnot(all(is.finite(snaps$snap_m)), max(snaps$snap_m) <= cfg$max_snap_m,
          setequal(paste(snaps$mode, snaps$Record_ID), paste(manifest$mode, manifest$Record_ID)))
for (mode in cfg$modes) {
  five <- data$access[data$access$mode == mode & data$access$minutes == 5, ]
  ten <- data$access[data$access$mode == mode & data$access$minutes == 10, ]
  stopifnot(sf::st_area(ten) > sf::st_area(five))
  outside <- suppressWarnings(sf::st_difference(sf::st_geometry(five), sf::st_geometry(ten)))
  stopifnot(sum(as.numeric(sf::st_area(outside))) < as.numeric(sf::st_area(five)) * 0.01)
}
# Reductions remain clipped to the study geography, regardless of the destination buffer.
stopifnot(all(lengths(sf::st_covered_by(data$access, sf::st_buffer(data$region, 1))) == 1),
          all(lengths(sf::st_covered_by(data$urban, sf::st_buffer(data$region, 1))) == 1),
          all(lengths(sf::st_covered_by(data$tracts, sf::st_buffer(data$region, 1))) == 1),
          all(lengths(sf::st_intersects(data$stores, sf::st_buffer(data$region, cfg$drive_buffer_m))) == 1))
cat("Day 09 retailer, inbound-routing, completeness and geometry checks passed\n")
