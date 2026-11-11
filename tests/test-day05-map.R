# Dependency-free unit checks for Day 05. Run from the repository root.
source("posts/2026-11-05-30daymap-05-senses-sight/render-map.R")
cfg <- day05_config()
stopifnot(cfg$eye_m == 1.6, cfg$clear_m == 15, cfg$footprint_buffer_m == 5, cfg$crs == "EPSG:26916",
          identical(names(cfg$colors), c("devou", "eden", "mount_echo")))

# Committed inputs: three OSM overlooks, five landmarks, and lidar reductions for all 15 pairs.
p <- read_day05_points()
stopifnot(identical(p$osm_id, c(3759254619, 2912935128, 2805238423)))
lm <- read_landmarks()
stopifnot(identical(lm$key, day05_landmark_keys()))
tops <- utils::read.csv(file.path(day05_root, "landmark-tops.csv"))
stopifnot(identical(tops$key, lm$key), all(tops$z > 150), all(tops$n_points > 1000))
prof <- utils::read.csv(file.path(day05_root, "sightline-profiles.csv"))
pairs <- unique(prof[c("from", "to")])
stopifnot(nrow(pairs) == 15L, setequal(pairs$from, p$key), setequal(pairs$to, lm$key))
for (i in seq_len(nrow(pairs))) {
  d <- prof$d[prof$from == pairs$from[i] & prof$to == pairs$to[i]]
  stopifnot(d[1] == 0.5, all(diff(d) == 1))
}
nodes <- utils::read.csv(file.path(day05_root, "ept-nodes.csv"))
stopifnot(nrow(nodes) > 1000L, !anyDuplicated(nodes),
          all(nodes$unit %in% c("OH_StatewideP3_6_B21", "KY_Western_1_A22")))

# Curvature with refraction lowers ground 8 km away by about 4.4 m.
stopifnot(abs(8000^2 * (1 - 0.13) / (2 * 6371008.8) - 4.37) < 0.01)

# visible_top: a 100 m landmark 1000 m away, eye at 101.6 m over ground at 100 m.
dd <- seq(0.5, 999.5, 1)
flat <- rep(100, length(dd))
r <- visible_top(dd, flat, 101.6, 1000, 200, 100, k = 0, radius_m = Inf)
stopifnot(abs(r$visible_m - 100) < 1e-9, is.na(r$blocker))
# A 30 m wall in bin 500 (d = 499.5 m) hides everything below 101.6 + 28.4 * 1000 / 499.5 m.
wall <- flat
wall[500] <- 130
r <- visible_top(dd, wall, 101.6, 1000, 200, 100, k = 0, radius_m = Inf)
low <- 101.6 + 28.4 * 1000 / 499.5
stopifnot(abs(r$lowest - low) < 1e-9, abs(r$visible_m - (200 - low)) < 1e-9, r$blocker == 500L)
# A wall tall enough to reach above the top hides it completely.
wall[500] <- 160
stopifnot(visible_top(dd, wall, 101.6, 1000, 200, 100, k = 0, radius_m = Inf)$visible_m == 0)
# Excluded samples (NA) never block.
wall[500] <- NA
stopifnot(abs(visible_top(dd, wall, 101.6, 1000, 200, 100, k = 0, radius_m = Inf)$visible_m - 100) < 1e-9)
# Over flat ground, curvature alone hides the base of a 5 m landmark 10 km away. The deciding
# horizon sits at d* = sqrt(1.6 / c) with c = (1 - k) / (2 R), leaving about 3.2 m in view.
c0 <- (1 - 0.13) / (2 * 6371008.8)
expect <- (105 - c0 * 1e8) - (101.6 - 3.2 * 1e4 / sqrt(1.6 / c0))
dk <- seq(0.5, 9999.5, 1)
far <- visible_top(dk, rep(100, length(dk)), 101.6, 10000, 105, 100)
stopifnot(abs(far$visible_m - expect) < 0.01, abs(expect - 3.18) < 0.01,
          visible_top(dk, rep(100, length(dk)), 101.6, 10000, 105, 100, k = 0, radius_m = Inf)$visible_m == 5)

# Geometry helpers on a unit square and a triangle.
sq <- rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0))
stopifnot(identical(point_in_ring(c(0.5, 1.5, -0.1), c(0.5, 0.5, 0.5), sq), c(TRUE, FALSE, FALSE)))
tri <- rbind(c(0, 0), c(4, 0), c(0, 4), c(0, 0))
stopifnot(identical(point_in_ring(c(1, 3), c(1, 3), tri), c(TRUE, FALSE)))
stopifnot(isTRUE(all.equal(ring_distance(c(0.5, 2, 0.5), c(0.5, 0.5, -3), sq), c(0.5, 1, 3))))

cat("Day 05 unit checks passed\n")
