#!/usr/bin/env Rscript
# Day 05 lidar acquisition: USGS 3DEP point clouds (Entwine Point Tiles on AWS Open Data) reduced to
# the committed 1 m sightline profiles and landmark tops. Needs network access and the rlas and curl
# packages. The post render never runs this; it reads the committed CSV outputs and the DEM tile.
# Run from the repository root: sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/acquire-lidar.R
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
source("posts/2026-11-05-30daymap-05-senses-sight/render-map.R")

lidar_config <- function() {
  list(
    base = "https://s3-us-west-2.amazonaws.com/usgs-lidar-public",
    units = c("OH_StatewideP3_6_B21", "KY_Western_1_A22"),
    cache_dir = "data/30daymap/2026/day05/ept",
    pad_m = 8, step_m = 5, half_width_m = 1.5, bin_m = 1,
    landmark_ways = data.frame(
      key = c("carew", "gat", "union_terminal", "cathedral"),
      label = c("Carew Tower", "Great American Tower", "Union Terminal", "Cathedral Basilica"),
      osm_id = c(91292276, 91493361, 27669543, 123059448)
    ),
    bridge_way = 567780747, tower_box_m = 12
  )
}

check_lidar_dependencies <- function() {
  needed <- c("rlas", "curl", "terra", "jsonlite", "digest")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing packages for lidar acquisition: ", paste(missing, collapse = ", "),
         ". See tasks/30daymap-r-runtime.md (Day 05).", call. = FALSE)
  }
}

fetch_osm_way <- function(id) {
  x <- jsonlite::fromJSON(sprintf("https://api.openstreetmap.org/api/0.6/way/%.0f/full.json", id),
                          simplifyVector = FALSE)$elements
  way <- Filter(function(e) e$type == "way", x)[[1]]
  nodes <- Filter(function(e) e$type == "node", x)
  lookup <- setNames(lapply(nodes, function(n) c(n$lon, n$lat)), vapply(nodes, function(n) format(n$id, scientific = FALSE), ""))
  ring <- do.call(rbind, lookup[vapply(way$nodes, function(n) format(n, scientific = FALSE), "")])
  list(ring = ring, version = way$version)
}

# Square ring (lon/lat) of half-width h metres around a UTM point.
utm_box_ring <- function(xy, h, cfg = day05_config()) {
  m <- rbind(xy + c(-h, -h), xy + c(h, -h), xy + c(h, h), xy + c(-h, h), xy + c(-h, -h))
  terra::project(m, from = cfg$crs, to = "EPSG:4269")
}

# EPT nodes (all depths) whose cells touch pad-boxes around the given UTM points.
ept_select <- function(pts_utm, lcfg = lidar_config(), cfg = day05_config()) {
  merc <- terra::project(pts_utm, from = cfg$crs, to = "EPSG:3857")
  pad <- lcfg$pad_m
  per_unit <- lapply(lcfg$units, function(u) {
    b <- jsonlite::fromJSON(file.path(lcfg$base, u, "ept.json"))$bounds
    width <- b[4] - b[1]
    cells_cache <- new.env()
    cells <- function(depth) {
      key <- as.character(depth)
      if (!exists(key, envir = cells_cache, inherits = FALSE)) {
        size <- width / 2^depth
        x0 <- floor((merc[, 1] - pad - b[1]) / size)
        x1 <- floor((merc[, 1] + pad - b[1]) / size)
        y0 <- floor((merc[, 2] - pad - b[2]) / size)
        y1 <- floor((merc[, 2] + pad - b[2]) / size)
        span <- max(x1 - x0, y1 - y0)
        hits <- unlist(lapply(0:span, function(i) {
          lapply(0:span, function(j) {
            ok <- x0 + i <= x1 & y0 + j <= y1
            paste(x0[ok] + i, y0[ok] + j, sep = "-")
          })
        }))
        assign(key, unique(hits), envir = cells_cache)
      }
      get(key, envir = cells_cache)
    }
    touches <- function(node) {
      k <- as.integer(strsplit(node, "-")[[1]])
      paste(k[2], k[3], sep = "-") %in% cells(k[1])
    }
    queue <- "0-0-0-0"
    found <- list()
    while (length(queue)) {
      h <- jsonlite::fromJSON(file.path(lcfg$base, u, "ept-hierarchy", paste0(queue[1], ".json")))
      queue <- queue[-1]
      keys <- names(h)[vapply(names(h), touches, logical(1))]
      counts <- unlist(h[keys])
      queue <- c(queue, keys[counts == -1])
      found[[length(found) + 1L]] <- keys[counts > 0]
    }
    data.frame(unit = u, key = unique(unlist(found)), stringsAsFactors = FALSE)
  })
  do.call(rbind, per_unit)
}

node_path <- function(nodes, lcfg = lidar_config()) file.path(lcfg$cache_dir, nodes$unit, paste0(nodes$key, ".laz"))

is_laz <- function(path) {
  file.exists(path) && file.size(path) > 4 && identical(readBin(path, "raw", 4), charToRaw("LASF"))
}

ept_fetch <- function(nodes, lcfg = lidar_config()) {
  paths <- node_path(nodes, lcfg)
  for (d in unique(dirname(paths))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  res <- NULL
  # S3 occasionally drops a transfer; retry what is still missing a few times.
  for (attempt in 1:3) {
    need <- !vapply(paths, is_laz, logical(1))
    if (!any(need)) break
    urls <- file.path(lcfg$base, nodes$unit[need], "ept-data", paste0(nodes$key[need], ".laz"))
    res <- curl::multi_download(urls, paths[need], progress = FALSE)
  }
  bad <- which(!vapply(paths, is_laz, logical(1)))
  if (length(bad)) {
    failed <- res[match(normalizePath(paths[bad], mustWork = FALSE), res$destfile), ]
    stop(length(bad), " EPT nodes failed to download, e.g. ", paths[bad[1]], " (status ",
         failed$status_code[1], ", ", failed$error[1], ")", call. = FALSE)
  }
  paths
}

# Node bounding boxes in UTM, for cheap overlap tests before reading points.
node_boxes <- function(paths, cfg = day05_config()) {
  t(vapply(paths, function(p) {
    h <- rlas::read.lasheader(p)
    m <- terra::project(cbind(c(h[["Min X"]], h[["Max X"]]), c(h[["Min Y"]], h[["Max Y"]])),
                        from = "EPSG:3857", to = cfg$crs)
    c(range(m[, 1]), range(m[, 2]))
  }, numeric(4)))
}

read_node_utm <- function(path, cfg = day05_config()) {
  las <- rlas::read.las(path, select = "xyz", filter = "-drop_class 7 18 -drop_withheld")
  if (!nrow(las)) return(NULL)
  xy <- terra::project(as.matrix(las[, c("X", "Y")]), from = "EPSG:3857", to = cfg$crs)
  list(x = xy[, 1], y = xy[, 2], z = las$Z)
}

overlapping <- function(boxes, xr, yr) which(boxes[, 1] <= xr[2] & boxes[, 2] >= xr[1] & boxes[, 3] <= yr[2] & boxes[, 4] >= yr[1])

# All lidar points inside a UTM polygon.
points_in_ring <- function(ring, paths, boxes) {
  parts <- lapply(overlapping(boxes, range(ring[, 1]), range(ring[, 2])), function(i) {
    p <- read_node_utm(paths[i])
    if (is.null(p)) return(NULL)
    inside <- point_in_ring(p$x, p$y, ring)
    cbind(p$x[inside], p$y[inside], p$z[inside])
  })
  do.call(rbind, parts)
}

# Bridge towers: the highest lidar point on each half of the OSM main-span line. Returns the north
# tower top and the spacing between the two peaks (a check against the 322 m main span).
locate_tower <- function(span_lonlat, paths, boxes, cfg = day05_config()) {
  ends <- day05_to_utm(span_lonlat[c(1, nrow(span_lonlat)), , drop = FALSE])
  north <- if (ends[1, 2] > ends[2, 2]) ends[1, ] else ends[2, ]
  south <- if (ends[1, 2] > ends[2, 2]) ends[2, ] else ends[1, ]
  u <- (south - north) / sqrt(sum((south - north)^2))
  n <- c(-u[2], u[1]) * 20
  mid <- (north + south) / 2
  peak <- function(a, b) {
    pts <- points_in_ring(rbind(a + n, b + n, b - n, a - n, a + n), paths, boxes)
    pts[which.max(pts[, 3]), 1:2]
  }
  north_top <- peak(north, mid)
  south_top <- peak(mid, south)
  list(north = north_top, spacing_m = round(sqrt(sum((north_top - south_top)^2)), 1))
}

# Median height of lidar ground returns (class 2) above the bare-earth DEM, over a spread of nodes.
ground_minus_dem <- function(paths, cfg = day05_config()) {
  dem <- terra::rast(file.path(cfg$cache_dir, cfg$tile))
  pick <- paths[unique(round(seq(1, length(paths), length.out = min(100, length(paths)))))]
  diffs <- lapply(pick, function(p) {
    las <- rlas::read.las(p, select = "xyz", filter = "-keep_class 2")
    if (!nrow(las)) return(NULL)
    xy <- terra::project(as.matrix(las[, c("X", "Y")]), from = "EPSG:3857", to = terra::crs(dem))
    las$Z - terra::extract(dem, xy, method = "bilinear")[, 1]
  })
  round(stats::median(unlist(diffs), na.rm = TRUE), 2)
}

landmark_tops <- function(landmarks, paths, boxes, cfg = day05_config()) {
  rows <- lapply(seq_along(landmarks$key), function(i) {
    ring <- day05_to_utm(landmarks$ring[[i]])
    pts <- points_in_ring(ring, paths, boxes)
    ztop <- unname(stats::quantile(pts[, 3], 0.999))
    hi <- pts[pts[, 3] >= ztop, , drop = FALSE]
    data.frame(key = landmarks$key[i], x = round(mean(hi[, 1]), 2), y = round(mean(hi[, 2]), 2),
               z = round(ztop, 2), n_points = nrow(pts))
  })
  do.call(rbind, rows)
}

# Highest lidar return in 1 m bins within half_width of each eye -> top line.
sightline_profiles <- function(oxy, tops, paths, boxes, lcfg = lidar_config()) {
  pairs <- expand.grid(from = rownames(oxy), to = tops$key, stringsAsFactors = FALSE)
  out <- lapply(seq_len(nrow(pairs)), function(i) {
    o <- oxy[pairs$from[i], ]
    t <- unlist(tops[tops$key == pairs$to[i], c("x", "y")])
    D <- sqrt(sum((t - o)^2))
    u <- (t - o) / D
    zmax <- rep(-Inf, ceiling(D / lcfg$bin_m))
    near <- overlapping(boxes, range(o[1], t[1]) + c(-5, 5), range(o[2], t[2]) + c(-5, 5))
    for (j in near) {
      p <- read_node_utm(paths[j])
      if (is.null(p)) next
      s <- (p$x - o[1]) * u[1] + (p$y - o[2]) * u[2]
      cr <- (p$x - o[1]) * -u[2] + (p$y - o[2]) * u[1]
      keep <- which(abs(cr) <= lcfg$half_width_m & s >= 0 & s < D)
      if (!length(keep)) next
      mx <- tapply(p$z[keep], floor(s[keep] / lcfg$bin_m) + 1L, max)
      idx <- as.integer(names(mx))
      zmax[idx] <- pmax(zmax[idx], mx)
    }
    data.frame(from = pairs$from[i], to = pairs$to[i], d = (seq_along(zmax) - 0.5) * lcfg$bin_m,
               z = ifelse(is.finite(zmax), round(zmax, 2), NA))
  })
  do.call(rbind, out)
}

corridor_points <- function(oxy, targets_xy, lcfg = lidar_config()) {
  segs <- lapply(rownames(oxy), function(f) {
    lapply(seq_len(nrow(targets_xy)), function(k) {
      o <- oxy[f, ]
      t <- targets_xy[k, ]
      s <- seq(0, 1, length.out = ceiling(sqrt(sum((t - o)^2)) / lcfg$step_m) + 1)
      cbind(o[1] + s * (t[1] - o[1]), o[2] + s * (t[2] - o[2]))
    })
  })
  do.call(rbind, unlist(segs, recursive = FALSE))
}

ring_grid <- function(ring_utm, step = 4) {
  as.matrix(expand.grid(seq(min(ring_utm[, 1]) - 5, max(ring_utm[, 1]) + 5, by = step),
                        seq(min(ring_utm[, 2]) - 5, max(ring_utm[, 2]) + 5, by = step)))
}

refresh_landmarks <- function(lcfg = lidar_config(), cfg = day05_config()) {
  ways <- lcfg$landmark_ways
  osm <- lapply(ways$osm_id, fetch_osm_way)
  span <- fetch_osm_way(lcfg$bridge_way)
  areas <- rbind(do.call(rbind, lapply(osm, function(w) ring_grid(day05_to_utm(w$ring)))), ring_grid(day05_to_utm(span$ring)))
  paths <- ept_fetch(ept_select(areas, lcfg))
  tower <- locate_tower(span$ring, paths, node_boxes(paths))
  features <- c(
    lapply(seq_len(nrow(ways)), function(i) {
      list(key = ways$key[i], label = ways$label[i], source = sprintf("OSM way %.0f v%d", ways$osm_id[i], osm[[i]]$version),
           ring = osm[[i]]$ring)
    }),
    list(list(key = "roebling_n", label = "Roebling Bridge north tower",
              source = sprintf("3DEP lidar peak on north half of OSM way %.0f v%d", lcfg$bridge_way, span$version),
              ring = utm_box_ring(tower$north, lcfg$tower_box_m)))
  )
  write_landmarks(features)
  tower$spacing_m
}

write_landmarks <- function(features, path = file.path(day05_root, "landmarks.geojson")) {
  fc <- list(type = "FeatureCollection", features = lapply(features, function(f) {
    list(type = "Feature", properties = list(key = f$key, label = f$label, source = f$source),
         geometry = list(type = "Polygon", coordinates = list(round(unname(f$ring), 7))))
  }))
  writeLines(jsonlite::toJSON(fc, auto_unbox = TRUE, digits = NA, pretty = TRUE), path)
}

acquire_day05_lidar <- function(refresh = FALSE, lcfg = lidar_config(), cfg = day05_config()) {
  check_lidar_dependencies()
  network <- terra::projNetwork()
  suppressMessages(terra::projNetwork(FALSE))
  if (isTRUE(network)) on.exit(suppressMessages(terra::projNetwork(TRUE)), add = TRUE)
  tower_spacing <- if (refresh) refresh_landmarks(lcfg, cfg) else NULL
  landmarks <- read_landmarks()
  points <- read_day05_points()
  oxy <- day05_to_utm(points[c("lon", "lat")])
  rownames(oxy) <- points$key
  # Footprints first (tops), then the eye -> top corridors.
  fp_nodes <- ept_select(do.call(rbind, lapply(landmarks$ring, function(r) ring_grid(day05_to_utm(r)))), lcfg)
  fp_paths <- ept_fetch(fp_nodes)
  tops <- landmark_tops(landmarks, fp_paths, node_boxes(fp_paths))
  corridor_nodes <- ept_select(corridor_points(oxy, as.matrix(tops[c("x", "y")])), lcfg)
  nodes <- unique(rbind(fp_nodes, corridor_nodes))
  nodes <- nodes[order(nodes$unit, nodes$key), ]
  paths <- ept_fetch(nodes)
  profiles <- sightline_profiles(oxy, tops, paths, node_boxes(paths), lcfg)
  utils::write.csv(nodes, file.path(day05_root, "ept-nodes.csv"), row.names = FALSE)
  utils::write.csv(tops, file.path(day05_root, "landmark-tops.csv"), row.names = FALSE)
  utils::write.csv(profiles, file.path(day05_root, "sightline-profiles.csv"), row.names = FALSE, na = "")
  manifest <- paste(nodes$unit, nodes$key, vapply(paths, digest::digest, "", algo = "sha256", file = TRUE))
  snap_path <- file.path(day05_root, "source-snapshot.json")
  snap <- jsonlite::fromJSON(snap_path, simplifyVector = FALSE)
  manifest_sha256 <- digest::digest(paste(manifest, collapse = "\n"), algo = "sha256", serialize = FALSE)
  if (!is.null(snap$lidar$manifest_sha256) && !identical(snap$lidar$manifest_sha256, manifest_sha256)) {
    warning("EPT node manifest changed from the recorded snapshot: review the matrix, prose and figure.", call. = FALSE)
  }
  snap$lidar$retrieved_utc <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  snap$lidar$nodes <- nrow(nodes)
  snap$lidar$manifest_sha256 <- manifest_sha256
  snap$lidar$ground_minus_dem_median_m <- ground_minus_dem(paths)
  if (!is.null(tower_spacing)) snap$landmarks$tower_peak_spacing_m <- tower_spacing
  writeLines(jsonlite::toJSON(snap, auto_unbox = TRUE, pretty = TRUE), snap_path)
  message("Day 05 lidar reduced: ", nrow(nodes), " EPT nodes, ", nrow(profiles), " profile bins")
  invisible(list(nodes = nodes, tops = tops, profiles = profiles))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (any(args %in% c("--help", "-h"))) {
    cat("Usage: sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/acquire-lidar.R [--refresh-landmarks]\n",
        "Downloads USGS EPT nodes into data/30daymap/2026/day05/ept and rewrites the committed\n",
        "ept-nodes.csv, landmark-tops.csv, sightline-profiles.csv and the lidar entry of source-snapshot.json.\n",
        "--refresh-landmarks also rebuilds landmarks.geojson from the OSM API and the lidar tower peak.\n")
  } else {
    unknown <- setdiff(args, "--refresh-landmarks")
    if (length(unknown)) stop("Unknown argument: ", unknown[1], call. = FALSE)
    acquire_day05_lidar(refresh = "--refresh-landmarks" %in% args)
  }
}
