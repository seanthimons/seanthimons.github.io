# Dependency-free unit checks for Day 05. Run from the repository root.
source("posts/2026-11-05-30daymap-05-senses-sight/render-map.R")
cfg <- day05_config()
stopifnot(cfg$eye_m == 1.6, cfg$length_m == 8000, cfg$step_m == 10, cfg$crs == "EPSG:26916",
          identical(names(cfg$colors), c("devou", "eden", "mount_echo")))

# Point contract: three overlooks, one target, OSM identities fixed.
p <- read_day05_points()
stopifnot(identical(p$osm_id, c(3759254619, 2912935128, 2805238423, 567780747)),
          identical(p$role, c(rep("overlook", 3), "target")))

# No curvature (infinite radius): flat ground below the eye is entirely visible.
d <- seq(0, 1000, 10)
stopifnot(all(los_visible(d, rep(100, length(d)), 1.6, k = 0, radius_m = Inf)))
# The observer's own point is visible even with zero eye height (no 0/0 corruption).
stopifnot(all(los_visible(d, rep(100, length(d)), 0, k = 0, radius_m = Inf)))
# A 20 m peak at 310 m hides the flat ground behind it (seen from below, even a flat ridge top is hidden).
z <- rep(100, length(d)); z[d == 310] <- 120
v <- los_visible(d, z, 1.6, k = 0, radius_m = Inf)
stopifnot(all(v[d <= 310]), !any(v[d > 310 & d <= 1000]))
# Rising ground behind the ridge becomes visible once it clears the ridge's sightline.
z2 <- z; z2[d > 600] <- 100 + (d[d > 600] - 600) * 0.2
v2 <- los_visible(d, z2, 1.6, k = 0, radius_m = Inf)
stopifnot(!v2[d == 650], v2[d == 1000])
# Curvature with refraction lowers ground 8 km away by about 4.4 m.
drop <- 8000^2 * (1 - 0.13) / (2 * 6371008.8)
stopifnot(abs(drop - 4.37) < 0.01)
# Ground exactly level with the eye at 8 km is hidden only by curvature behind a bump.
d3 <- c(0, 4000, 8000); z3 <- c(100, 101.6 - 1.0, 101.6)
stopifnot(identical(los_visible(d3, z3, 1.6, k = 0, radius_m = Inf), c(TRUE, TRUE, TRUE)),
          identical(los_visible(d3, z3, 1.6), c(TRUE, TRUE, FALSE)))
stopifnot(inherits(try(los_visible(c(1, 2), c(1, 1), 1.6), silent = TRUE), "try-error"))

# Transects pass through the target at its distance and keep the step size.
t <- transect_xy(c(0, 0), c(300, 400), 1000, 10)
k <- which(t$d == 500)
stopifnot(t$target_d == 500, abs(t$x[k] - 300) < 1e-9, abs(t$y[k] - 400) < 1e-9,
          length(t$d) == 101L)
stopifnot(inherits(try(transect_xy(c(0, 0), c(3000, 4000), 1000, 10), silent = TRUE), "try-error"))

r <- day05_runs(c(TRUE, TRUE, FALSE, TRUE))
stopifnot(identical(r$start, c(1L, 3L, 4L)), identical(r$end, c(2L, 3L, 4L)))
cat("Day 05 unit checks passed\n")
