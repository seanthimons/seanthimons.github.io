# Run from the repository root with sh scripts/map-r.sh.
source("posts/2026-11-06-30daymap-06-vintage/render-map.R")
p <- read_day06_breweries()
stopifnot(nrow(p) == 13, !anyDuplicated(p$name), !anyNA(p[c("lon", "lat", "in_1903_source")]),
          setequal(p$city, c("Cincinnati", "Covington", "Newport")),
          setequal(p$placed_by, c("queen_city_address", "osm_feature", "osm_intersection")),
          all(nzchar(p$source_url)), all(nzchar(p$osm_url)), all(nzchar(p$placement_note)),
          all(grepl("^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", p$retrieved_date)))
# Reject broken reductions, including a duplicate firm, a missing coordinate and an invalid evidence label.
rejects <- function(x) {
  path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
  utils::write.csv(x, path, row.names = FALSE)
  inherits(try(read_day06_breweries(path), silent = TRUE), "try-error")
}
stopifnot(rejects(rbind(p, p[1, ])))
bad <- p; bad$lon[1] <- NA; stopifnot(rejects(bad))
bad <- p; bad$lat[1] <- 40; stopifnot(rejects(bad))
bad <- p; bad$placed_by[1] <- "guess"; stopifnot(rejects(bad))
# Geographic rings close, retain the requested extent and round-trip under projection.
r <- day06_rectangle(c(-85, -84, 39, 40), "EPSG:4326")
stopifnot(isTRUE(all.equal(unname(as.vector(terra::ext(r))), c(-85, -84, 39, 40))))
back <- terra::project(terra::project(r, "EPSG:26916"), "EPSG:4326")
stopifnot(max(abs(as.vector(terra::ext(back)) - as.vector(terra::ext(r)))) < 1e-7)
# Later company names must not receive their predecessors' 1903 flags.
stopifnot(!any(p$in_1903_source[p$name %in% c("Ohio Union", "Crown", "Phillip Jung")]),
          all(p$in_1903_source[p$name %in% c("Gambrinus", "Bavarian", "Jackson")]))
ex <- utils::read.csv(file.path(day06_root, "excluded-firms.csv"))
stopifnot(nrow(ex) == 10, !anyDuplicated(ex$name), !any(ex$name %in% p$name), all(nzchar(ex$reason)))
cat("Day 06 map contract and geometry checks passed\n")
