# Run from repository root: Rscript tests/test-day01-map.R
source("posts/2026-11-01-30daymap-01-points/render-map.R")
inputs <- read_day01("data/30daymap/2026/day01")
d <- inputs$events
stopifnot(nrow(d) == 3478L)
band <- d$latitude >= -24 & d$latitude <= -20
stopifnot(sum(band) == 1612L, any(d$depth[band] > 500), any(d$depth[band] < 30))
# Compare one degree of projected distance against an independent spherical
# great-circle calculation at the standard parallel (well under 0.01% error).
phi <- -21 * pi / 180
arc <- 2 * 6371.0088 * asin(cos(phi) * sin(pi / 360))
p <- project_day01(c(-76, -75), c(-21, -21))
stopifnot(abs(diff(p[, 'x']) / arc - 1) < .0001, all(p[, 'y'] == 0))
# Altered raw inputs must fail before they can silently change the article.
local({
  scratch <- tempfile(); dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE))
  file.copy(inputs$paths, scratch)
  cat("\n", file = file.path(scratch, "earthquakes.csv"), append = TRUE)
  failure <- tryCatch({read_day01(scratch); NULL}, error = identity)
  stopifnot(inherits(failure, "error"), grepl("fingerprint", conditionMessage(failure)))
})
# Verify exported PNG signature and actual pixel dimensions without an image package.
local({
  con <- file("posts/2026-11-01-30daymap-01-points/artifacts/day01-andes-depth.png", "rb")
  on.exit(close(con))
  stopifnot(identical(readBin(con, 'raw', 8), as.raw(c(137,80,78,71,13,10,26,10))))
  seek(con, 16)
  stopifnot(identical(readBin(con, 'integer', 2, size = 4, endian = 'big'), c(1800L, 3000L)))
})
freeze <- jsonlite::fromJSON(paste0("_freeze/posts/2026-11-01-30daymap-01-points/",
  "2026-11-01-30daymap-01-points/execute-results/html.json"))
stopifnot(grepl("day01-andes-depth.png", freeze$result$markdown, fixed = TRUE),
          grepl("highlighted band", freeze$result$markdown, fixed = TRUE))
cat("PASS: Day01 snapshot, section, projection, changed-source rejection, PNG and executed freeze\n")
