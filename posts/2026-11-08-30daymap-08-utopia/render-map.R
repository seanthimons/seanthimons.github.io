#!/usr/bin/env Rscript
# Offline rendering from the committed GeoPackage and assessment reduction.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day08_root <- "posts/2026-11-08-30daymap-08-utopia"
day08_cache <- "data/30daymap/2026/day08"
day08_config <- function() list(
  crs = 5070L, cycle = "2024", organization = "21OHIO", bounds = c(-84.83, 38.39, -80.50, 42.1),
  background = "#102026", ink = "#ECE9DE", muted = "#A1B3B5", stream = "#BBD5D4",
  colors = c(supporting = "#46BE99", not_supporting = "#A76066", unknown = "#60747B")
)

# A unit supports the target only when every reported aquatic-life use is F.
# A known failure remains a failure even if another use is unassessed.
day08_status <- function(codes) {
  if (anyNA(codes) || !all(codes %in% c("F", "N", "I", "X"))) stop("Unexpected aquatic-life attainment code")
  if ("N" %in% codes) "not_supporting" else if (length(codes) && all(codes == "F")) "supporting" else "unknown"
}

read_day08 <- function() {
  cfg <- day08_config()
  records <- utils::read.csv(file.path(day08_root, "assessments.csv"), colClasses = "character")
  if (anyDuplicated(records$assessment_unit_id) || anyDuplicated(records$huc12) ||
      !all(records$status %in% names(cfg$colors)) || !all(records$reporting_cycle == cfg$cycle) ||
      !all(records$organization_id == cfg$organization) ||
      !all(records$report_status == "EPA Final Action") || !all(grepl("^[0-9]{12}$", records$huc12)))
    stop("Invalid watershed assessment reduction")
  gpkg <- file.path(day08_root, "ohio-map.gpkg")
  read <- function(layer) sf::st_read(gpkg, layer = layer, quiet = TRUE)
  watersheds <- read("watersheds")
  if (nrow(watersheds) != nrow(records) ||
      !identical(watersheds$assessment_unit_id, records$assessment_unit_id) ||
      !identical(watersheds$status, records$status) || any(sf::st_is_empty(watersheds)) ||
      !all(sf::st_is_valid(watersheds))) stop("Watershed geometry does not match assessment records")
  list(records = records, watersheds = watersheds, streams = read("streams"), ohio = read("ohio"),
       footprint = sf::st_union(sf::st_geometry(watersheds)))
}

verify_day08 <- function() {
  snapshot <- jsonlite::read_json(file.path(day08_root, "source-snapshot.json"), simplifyVector = TRUE)
  for (i in seq_len(nrow(snapshot$render_inputs))) {
    x <- snapshot$render_inputs[i, ]
    if (!file.exists(x$path) || digest::digest(file = x$path, algo = "sha256") != x$sha256)
      stop("Missing or changed input: ", x$path)
  }
  snapshot
}

draw_day08 <- function(data, snapshot, cfg = day08_config()) {
  counts <- table(factor(data$records$status, levels = names(cfg$colors)))
  total <- nrow(data$records); met <- unname(counts["supporting"])
  graphics::par(bg = cfg$background, family = "sans", mar = rep(0, 4), xpd = FALSE)
  bbox <- sf::st_bbox(data$footprint)
  padding <- 15000
  graphics::par(fig = c(0.05, 0.95, 0.29, 0.83), mar = rep(0, 4))
  graphics::plot.new()
  graphics::plot.window(c(bbox[1] - padding, bbox[3] + padding),
                        c(bbox[2] - padding, bbox[4] + padding), asp = 1, xaxs = "i", yaxs = "i")
  plot(data$footprint, add = TRUE, col = "#1A3037", border = NA)
  plot(sf::st_geometry(data$watersheds), add = TRUE,
       col = grDevices::adjustcolor(cfg$colors[data$watersheds$status], 0.64),
       border = grDevices::adjustcolor(cfg$background, 0.45), lwd = 0.1)
  plot(sf::st_geometry(data$streams), add = TRUE, col = grDevices::adjustcolor(cfg$stream, 0.60), lwd = 0.20)
  plot(data$footprint, add = TRUE, col = NA, border = "#70878B", lwd = 0.65)
  graphics::par(fig = c(0, 1, 0, 1), mar = rep(0, 4), new = TRUE, xpd = NA)
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  graphics::text(0.05, 0.971, "08 / UTOPIA     \u2022     OHIO", adj = 0, col = cfg$muted, cex = 0.85)
  graphics::text(0.05, 0.928, "Room for life", adj = 0, col = cfg$ink, cex = 2.25, font = 2)
  graphics::text(0.05, 0.893, "Utopia: every watershed supports its aquatic-life uses", adj = 0, col = cfg$ink, cex = 0.85)
  graphics::text(0.05, 0.848, sprintf("2024 / %s WATERSHED ASSESSMENT UNITS", format(total, big.mark = ",")),
                 adj = 0, col = cfg$muted, cex = 0.78)
  graphics::text(0.05, 0.232, sprintf("%.1f%%", 100 * met / total), adj = 0, col = cfg$colors[["supporting"]], cex = 2.5, font = 2)
  graphics::text(0.05, 0.194, sprintf("%s of %s units", met, format(total, big.mark = ",")),
                 adj = 0, col = cfg$ink, cex = 0.8)
  graphics::text(0.05, 0.171, "fully supporting", adj = 0, col = cfg$ink, cex = 0.8)
  graphics::text(0.43, 0.251, "REPORTED AQUATIC-LIFE SUPPORT", adj = 0, col = cfg$muted, cex = 0.67)
  legend <- c(sprintf("%s / every reported aquatic-life use fully supporting", counts["supporting"]),
              sprintf("%s / at least one aquatic-life use not supporting", counts["not_supporting"]),
              sprintf("%s / unassessed or insufficient information", counts["unknown"]))
  for (i in seq_along(legend)) {
    y <- 0.221 - (i - 1) * 0.031
    graphics::rect(0.43, y - 0.006, 0.45, y + 0.006, col = cfg$colors[i], border = NA)
    graphics::text(0.465, y, legend[i], adj = 0, col = cfg$ink, cex = 0.64)
  }
  graphics::text(0.05, 0.098, "Colour describes watershed reporting units, not every stream reach. Pale lines are named streams from Freshwater Explorer.",
                 adj = 0, col = cfg$muted, cex = 0.62)
  graphics::text(0.05, 0.079, "River and Great Lakes assessment units are outside this comparison. Full support is use-specific, not pristine condition.",
                 adj = 0, col = cfg$muted, cex = 0.62)
  graphics::text(0.05, 0.042, "EPA ATTAINS 2024 / EPA Freshwater Explorer / USGS WBD / Census boundary / NAD83 Conus Albers",
                 adj = 0, col = cfg$muted, cex = 0.63)
  graphics::text(0.05, 0.021, paste0("Retrieved ", snapshot$retrieval_dates, " / Sean Thimons / #30DayMapChallenge"),
                 adj = 0, col = cfg$muted, cex = 0.63)
}

render_day08 <- function() {
  snapshot <- verify_day08(); data <- read_day08(); cfg <- day08_config()
  out <- file.path(day08_root, "artifacts"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  save <- function(open) { open(); on.exit(grDevices::dev.off()); draw_day08(data, snapshot) }
  save(function() grDevices::png(file.path(out, "day08-room-for-life.png"), width = 3000, height = 3900,
                                  res = 300, type = "cairo", bg = cfg$background))
  save(function() grDevices::cairo_pdf(file.path(out, "day08-room-for-life.pdf"), width = 10, height = 13, bg = cfg$background))
  writeLines(trimws(capture.output(dput(list(R = R.version.string, sf = as.character(utils::packageVersion("sf")),
                                            external = sf::sf_extSoftVersion(), config = cfg))), which = "right"),
             file.path(out, "provenance.R"))
  invisible(data)
}
if (sys.nframe() == 0L) render_day08()
