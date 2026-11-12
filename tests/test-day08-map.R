# Run from the repository root with sh scripts/map-r.sh.
source("posts/2026-11-08-30daymap-08-utopia/render-map.R")
stopifnot(day08_status("F") == "supporting", day08_status(c("F", "F")) == "supporting",
          day08_status("N") == "not_supporting", day08_status(c("F", "N")) == "not_supporting",
          day08_status(c("N", "X")) == "not_supporting", day08_status("I") == "unknown",
          day08_status("X") == "unknown", day08_status(c("F", "X")) == "unknown",
          day08_status(character()) == "unknown",
          inherits(try(day08_status(NA_character_), silent = TRUE), "try-error"),
          inherits(try(day08_status("unexpected"), silent = TRUE), "try-error"))
snapshot <- verify_day08(); x <- read_day08()
stopifnot(nrow(x$records) == 1538, !anyDuplicated(x$records$assessment_unit_id),
          !anyDuplicated(x$records$huc12), nrow(x$watersheds) == 1538,
          sf::st_crs(x$watersheds)$epsg == 5070, sf::st_crs(x$streams)$epsg == 5070,
          all(sf::st_is_valid(x$streams)), !any(sf::st_is_empty(x$streams)))
counts <- table(factor(x$records$status, levels = c("supporting", "not_supporting", "unknown")))
stopifnot(identical(as.integer(counts), c(513L, 923L, 102L)), sum(counts) == 1538,
          abs(100 * counts[[1]] / sum(counts) - 33.35501) < 0.00001)
uses <- utils::read.csv(file.path(day08_root, "aquatic-uses.csv"))
for (i in seq_len(nrow(x$records))) {
  codes <- uses$code[uses$assessment_unit_id == x$records$assessment_unit_id[i]]
  stopifnot(day08_status(codes) == x$records$status[i])
}
excluded <- utils::read.csv(file.path(day08_root, "excluded-units.csv"))
stopifnot(nrow(excluded) == 62, all(excluded$type %in% c("RIVER", "GREAT LAKES OPEN WATER")),
          !any(excluded$assessment_unit_id %in% x$records$assessment_unit_id))
pages <- utils::read.csv(file.path(day08_root, "freshwater-pages.csv"))
stopifnot(!anyDuplicated(pages$page), all(pages$all_requested_ids_returned),
          all(pages$requested_ids == pages$returned_ids), sum(pages$returned_ids) == snapshot$coverage$freshwater_named_ids_bbox,
          snapshot$coverage$mapped_watershed_units + snapshot$coverage$excluded_units == snapshot$coverage$report_assessments)
# Spatial clipping may not create mapped land or stream lines outside the state.
outer <- sf::st_buffer(sf::st_geometry(x$ohio), 100)
stopifnot(all(lengths(sf::st_covered_by(x$watersheds, outer)) == 1),
          all(lengths(sf::st_covered_by(x$streams, outer)) == 1))
cat("Day 08 assessment, completeness and geometry checks passed\n")
