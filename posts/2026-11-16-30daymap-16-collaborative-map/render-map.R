#!/usr/bin/env Rscript
# Day 16: the river's ledger. A space-time cube along the Mississippi: EPA TRI surface-water discharges, USGS annual
# flood peaks and 7-day low flows, measured conductivity against EPA's modeled natural background, and USGS invasive
# species records, one extruded slab per site per year, stacked 1987 (bottom) to 2024 (top).
# acquire_day16() is the only network step; render_day16() reads the cache and committed reductions.
# Run from the repository root; sourcing only defines functions.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day16_root <- "posts/2026-11-16-30daymap-16-collaborative-map"

# St. Paul, MN to the Gulf. The committed CSVs and the snapshot are for this extent.
day16_config <- function() {
  list(
    label = "St. Paul, MN to the Gulf",
    states = c("MN", "WI", "IA", "IL", "MO", "KY", "TN", "AR", "MS", "LA"),
    # Main-stem discharge gage candidates; prepare keeps those with enough peaks in the study years.
    gages = c(
      "05331000", "05331580", "05344500", "05378500", "05389500", "05420500", "05474500", "05587450",
      "07010000", "07020500", "07022000", "07032000", "07047970", "07265450", "07289000", "07295100",
      "07374000", "07374525"
    ),
    window = c(xmin = -95, ymin = 28.9, xmax = -88, ymax = 45.05),
    hex_m = 12000, gage_radius_m = 5000,
    # Stems tie each column that starts after the first year to the ground (about a pixel wide at the opening zoom).
    stem_radius_m = 2000, stem_color = "#93a1ad", stem_opacity = 0.4,
    metres_per_year = c(`4` = 16000, `6` = 4000, `8` = 1000, `10` = 250, `12` = 60),
    camera = list(center = c(-90.9, 36.5), zoom = 5.15, pitch = 60, bearing = -78),
    years = 1987:2024,
    min_peak_years = 25,
    # Low water: the lowest 7-day mean daily discharge of each climatic year (April-March, labeled by the year it
    # starts, so one dry autumn and winter stays in one year). Years with fewer than low_min_days daily values are gaps.
    low_min_days = 350,
    # Invasive species from the USGS Nonindigenous Aquatic Species database (species_ID -> group).
    nas_species = c(`549` = "Invasive carp", `551` = "Invasive carp", `573` = "Invasive carp", `5` = "Zebra mussel"),
    nas_url = "https://nas.er.usgs.gov/api/v2/occurrence/search?species_ID=%s",
    nas_accuracy = c("Accurate", "Approximate"),
    nas_drop_status = c("failed", "eradicated", "extirpated", "stocked"),
    # Gages below the Old River Control Structure, which sets how much flow goes down the Atchafalaya instead.
    regulated = c("07295100", "07374000", "07374525"),
    # Specific conductance sites from the Water Quality Portal: named Mississippi, on the main stem, with enough
    # years. Sites of one organization within wq_cluster_m of each other become one column.
    wq_near_river_m = 3000,
    wq_min_years = 20,
    wq_cluster_m = 15000,
    wq_exclude_types = c("Riverine Impoundment", "Lake", "Reservoir"),
    wq_activity = c("Sample-Routine", "Field Msr/Obs"),
    wq_units = c("uS/cm", "uS/cm @25C", "umho/cm"),
    wq_min_visits = 6,
    # Credit names for Water Quality Portal organizations (USGS state offices collapse to USGS).
    wq_org_names = c(
      USGS = "USGS", UMRR_LTRM = "UMRR LTRM", MNPCA = "Minnesota PCA", WIDNR_WQX = "Wisconsin DNR",
      IL_EPA_WQX = "Illinois EPA"
    ),
    background_url = paste0(
      "https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/",
      "PredECHydroline/FeatureServer/0/query"
    ),
    crs = "EPSG:5070",
    corridor_m = 10000,
    # Slab thickness in years; the remainder is the gap between years.
    slab = 0.78,
    river_url = paste0(
      "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/",
      "ca96624a56bd078437bca8184e78163e5039ad19/geojson/ne_10m_rivers_lake_centerlines.geojson"
    ),
    cache_dir = "data/30daymap/2026/day16",
    background = "#0b0f14", ink = "#e9edf1", muted = "#93a1ad",
    gage_ramp = c("#18304f", "#2a6f9e", "#43b3d6", "#a9ecf7", "#ffffff"),
    gage_stops = c(0, 0.5, 0.75, 0.9, 1),
    low_ramp = c("#2a1d12", "#5e3c1f", "#a8682f", "#e8a95c", "#fff1cf"),
    nas_groups = c(`Invasive carp` = "#b8f53a", `Zebra mussel` = "#e04cff"),
    # Gap between split halves (floods/low water in "All", invasive groups always), as a share of the footprint width.
    half_gap = 0.05,
    # TRI slabs: color is the sector group discharging the most; width runs from tri_width[1] of the hexagon at
    # 1 lb to the full hexagon at 10^tri_log_max lb (log scale).
    tri_groups = c(
      Chemicals = "#ff7a45", `Energy & petroleum` = "#ffd166", Paper = "#7bd389",
      `Food & beverage` = "#f78fb3", Metals = "#9fb4d8", Other = "#a08c78"
    ),
    tri_width = c(0.3, 1),
    tri_log_max = 7.5,
    wq_ramp = c("#2b2540", "#4f3a7a", "#7d52b3", "#b57ee0", "#ecd2ff"),
    wq_stops = c(1.5, 2, 2.75, 3.5, 4.5)
  )
}

day16_tri_urls <- function(cfg = day16_config()) {
  grid <- expand.grid(year = cfg$years, state = cfg$states, stringsAsFactors = FALSE)
  setNames(
    sprintf("https://data.epa.gov/efservice/downloads/tri/mv_tri_basic_download/%d_%s/csv", grid$year, grid$state),
    sprintf("tri-%d-%s.csv", grid$year, grid$state)
  )
}

day16_nas_urls <- function(cfg = day16_config()) {
  ids <- names(cfg$nas_species)
  setNames(sprintf(cfg$nas_url, ids), sprintf("nas-%s.json", ids))
}

day16_urls <- function(cfg = day16_config()) {
  c(day16_tri_urls(cfg), day16_nas_urls(cfg), `rivers-natural-earth.geojson` = cfg$river_url)
}

# Cache every file source that is not already cached.
day16_download <- function(cfg = day16_config()) {
  dir.create(cfg$cache_dir, recursive = TRUE, showWarnings = FALSE)
  urls <- day16_urls(cfg)
  old <- options(timeout = max(240, getOption("timeout")))
  on.exit(options(old))
  for (f in names(urls)) {
    dest <- file.path(cfg$cache_dir, f)
    if (file.exists(dest)) next
    tmp <- paste0(dest, ".part")
    status <- tryCatch(
      download.file(urls[[f]], tmp, method = "libcurl", mode = "wb", quiet = TRUE),
      error = function(e) 1L
    )
    if (status != 0 || !file.rename(tmp, dest)) stop("Download failed: ", f)
  }
}

day16_climate_year <- function(date) {
  d <- as.Date(date)
  as.integer(format(d, "%Y")) - (as.integer(format(d, "%m")) < 4)
}

# Annual 7-day low flow per gage and climatic year from daily mean discharge (site, date, cfs, estimated). The 7-day
# mean runs over each gage's whole record and counts only when all seven calendar days have values; a window belongs
# to the climatic year of its last day. n_days counts the daily values inside that climatic year; n_estimated counts
# the estimated days (often ice) inside the lowest window.
day16_low_flow <- function(daily) {
  daily <- daily[!is.na(daily$cfs), ]
  out <- lapply(split(daily, daily$site), function(x) {
    day <- as.integer(as.Date(x$date))
    if (anyDuplicated(day)) stop("Duplicate daily values at ", x$site[1])
    span <- seq(min(day), max(day))
    q <- rep(NA_real_, length(span))
    q[day - min(day) + 1] <- x$cfs
    est <- rep(0, length(span))
    est[day - min(day) + 1] <- x$estimated
    week <- function(v) if (length(v) >= 7) as.numeric(stats::filter(v, rep(1, 7), sides = 1)) else rep(NA_real_, length(v))
    m7 <- week(q) / 7
    e7 <- week(est)
    cy <- day16_climate_year(as.Date(span, origin = "1970-01-01"))
    n_days <- tapply(!is.na(q), cy, sum)
    ok <- !is.na(m7)
    if (!any(ok)) return(NULL)
    rows <- lapply(split(which(ok), cy[ok]), function(i) i[which.min(m7[i])])
    i <- unlist(rows)
    data.frame(
      site = x$site[1], climate_year = as.integer(names(rows)), n_days = as.integer(n_days[names(rows)]),
      min7_cfs = round(m7[i], 1), min7_end = as.character(as.Date(span[i], origin = "1970-01-01")),
      n_estimated = as.integer(e7[i])
    )
  })
  out <- do.call(rbind, out)
  out <- out[order(out$site, out$climate_year), ]
  rownames(out) <- NULL
  out
}

# Writes low-flow.csv. Run alone, follow with snapshot_day16() so the snapshot hash matches.
day16_acquire_low_flow <- function(cfg = day16_config()) {
  daily <- dataRetrieval::read_waterdata_daily(
    monitoring_location_id = paste0("USGS-", cfg$gages), parameter_code = "00060", statistic_id = "00003",
    time = c(sprintf("%d-03-26", min(cfg$years)), sprintf("%d-03-31", max(cfg$years) + 1)), skipGeometry = TRUE
  )
  daily <- data.frame(
    site = sub("^USGS-", "", daily$monitoring_location_id), date = as.character(daily$time), cfs = daily$value,
    estimated = grepl("ESTIMATED", daily$qualifier, fixed = TRUE)
  )
  utils::write.csv(day16_low_flow(daily), file.path(day16_root, "low-flow.csv"), row.names = FALSE)
}

# Network step: cache file sources, fetch USGS peaks, daily low flows, gage metadata and conductivity into
# committed CSVs.
acquire_day16 <- function(cfg = day16_config()) {
  day16_download(cfg)
  day16_acquire_low_flow(cfg)
  ids <- paste0("USGS-", cfg$gages)
  sites <- dataRetrieval::read_waterdata_monitoring_location(monitoring_location_id = ids)
  xy <- sf::st_coordinates(sites)
  gages <- data.frame(
    site = sub("^USGS-", "", sites$monitoring_location_id),
    name = sites$monitoring_location_name,
    drainage_sq_mi = sites$drainage_area,
    lon = round(xy[, 1], 6),
    lat = round(xy[, 2], 6)
  )
  peaks <- dataRetrieval::read_waterdata_peaks(monitoring_location_id = ids, parameter_code = "00060")
  peaks <- sf::st_drop_geometry(peaks)
  peaks <- data.frame(
    site = sub("^USGS-", "", peaks$monitoring_location_id),
    water_year = peaks$water_year,
    peak_date = as.character(peaks$time),
    peak_cfs = peaks$value,
    qualifier = peaks$qualifier
  )
  peaks <- peaks[order(peaks$site, peaks$water_year), ]
  wq_sites <- day16_discover_wq(cfg)
  wq_ids <- unlist(strsplit(wq_sites$members, ";", fixed = TRUE))
  sc <- dataRetrieval::readWQPdata(
    siteid = wq_ids, CharacteristicName = "Specific conductance",
    startDateLo = sprintf("%d-10-01", min(cfg$years) - 1), startDateHi = sprintf("%d-09-30", max(cfg$years))
  )
  conductivity <- data.frame(
    site = sc$MonitoringLocationIdentifier,
    date = as.character(sc$ActivityStartDate),
    activity_type = sc$ActivityTypeCode,
    depth = sc$ActivityDepthHeightMeasure.MeasureValue,
    value = as.numeric(sc$ResultMeasureValue),
    unit = sc$ResultMeasure.MeasureUnitCode
  )
  conductivity <- conductivity[order(conductivity$site, conductivity$date, conductivity$depth), ]
  gages <- gages[match(cfg$gages, gages$site), ]
  utils::write.csv(gages[!is.na(gages$site), ], file.path(day16_root, "gages.csv"), row.names = FALSE)
  utils::write.csv(peaks, file.path(day16_root, "peaks.csv"), row.names = FALSE)
  utils::write.csv(conductivity, file.path(day16_root, "conductivity.csv"), row.names = FALSE)
  utils::write.csv(wq_sites, file.path(day16_root, "wq-sites.csv"), row.names = FALSE)
  snapshot_day16(cfg)
}

# Main-stem conductivity columns from the Water Quality Portal: sites named Mississippi, within
# wq_near_river_m of the mapped river, with wq_min_years years of 6+ results; one organization's sites within
# wq_cluster_m of each other share a column at their centroid, scored against the background there.
day16_discover_wq <- function(cfg) {
  river <- day16_river(cfg)
  bands <- seq(cfg$window[["ymin"]], cfg$window[["ymax"]], by = 1.5)
  bands <- unique(c(bands, cfg$window[["ymax"]]))
  summ <- do.call(rbind, lapply(seq_len(length(bands) - 1), function(i) {
    band <- sf::st_as_sfc(sf::st_bbox(
      c(xmin = cfg$window[["xmin"]], xmax = cfg$window[["xmax"]], ymin = bands[i], ymax = bands[i + 1]),
      crs = 4326
    ))
    part <- sf::st_intersection(sf::st_transform(river, 4326), band)
    if (!length(part) || all(sf::st_is_empty(part))) return(NULL)
    bb <- round(as.numeric(sf::st_bbox(part)) + c(-0.05, -0.05, 0.05, 0.05), 4)
    x <- tryCatch(
      dataRetrieval::readWQPsummary(bBox = bb, CharacteristicName = "Specific conductance"),
      error = function(e) NULL
    )
    if (is.null(x) || !nrow(x)) return(NULL)
    x[, c("MonitoringLocationIdentifier", "MonitoringLocationName", "OrganizationIdentifier",
          "MonitoringLocationLatitude", "MonitoringLocationLongitude", "YearSummarized", "ResultCount")]
  }))
  summ <- summ[!duplicated(summ[, c("MonitoringLocationIdentifier", "YearSummarized")]), ]
  summ <- summ[grepl("mississippi", summ$MonitoringLocationName, ignore.case = TRUE) &
                 !grepl("outlet|canal|slough|chute|bayou|creek|trib", summ$MonitoringLocationName, ignore.case = TRUE), ]
  good <- summ[summ$YearSummarized %in% cfg$years & summ$ResultCount >= 6, ]
  years <- tapply(good$YearSummarized, good$MonitoringLocationIdentifier, function(y) length(unique(y)))
  keep <- names(years)[years >= cfg$wq_min_years]
  sites <- summ[summ$MonitoringLocationIdentifier %in% keep & !duplicated(summ$MonitoringLocationIdentifier), ]
  pts <- sf::st_transform(sf::st_as_sf(
    sites, coords = c("MonitoringLocationLongitude", "MonitoringLocationLatitude"), crs = 4326, remove = FALSE
  ), cfg$crs)
  sites <- sites[as.numeric(sf::st_distance(pts, river)) <= cfg$wq_near_river_m, ]
  meta <- dataRetrieval::whatWQPsites(siteid = sites$MonitoringLocationIdentifier)
  bad <- meta$MonitoringLocationIdentifier[meta$MonitoringLocationTypeName %in% cfg$wq_exclude_types]
  sites <- sites[!sites$MonitoringLocationIdentifier %in% bad, ]
  if (!nrow(sites)) stop("No conductivity sites met the rules")

  groups <- do.call(rbind, lapply(split(sites, sites$OrganizationIdentifier), function(o) {
    xy <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(
      o, coords = c("MonitoringLocationLongitude", "MonitoringLocationLatitude"), crs = 4326
    ), cfg$crs))
    cl <- if (nrow(o) > 1) stats::cutree(stats::hclust(stats::dist(xy), method = "single"), h = cfg$wq_cluster_m) else 1L
    do.call(rbind, lapply(split(seq_len(nrow(o)), cl), function(i) {
      m <- o[i, ]
      data.frame(
        group = if (nrow(m) == 1) sprintf("%s · %s", m$OrganizationIdentifier, m$MonitoringLocationName)
                else sprintf("%s · %d sites near %s", m$OrganizationIdentifier[1], nrow(m), m$MonitoringLocationName[1]),
        org = m$OrganizationIdentifier[1],
        members = paste(sort(m$MonitoringLocationIdentifier), collapse = ";"),
        n_sites = nrow(m),
        lon = round(mean(m$MonitoringLocationLongitude), 6),
        lat = round(mean(m$MonitoringLocationLatitude), 6)
      )
    }))
  }))
  bg <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) day16_background(groups$lon[i], groups$lat[i], cfg)))
  groups <- cbind(groups, bg)
  groups[!is.na(groups$background_us_cm), ]
}

# EPA Freshwater Explorer background: the nearest NHDPlus V2 Mississippi River segment to a point, or NA.
day16_background <- function(lon, lat, cfg) {
  seg <- NULL
  for (pad in c(0.03, 0.08)) {
    query <- paste0(
      cfg$background_url, "?geometryType=esriGeometryEnvelope&inSR=4326&outSR=4326",
      "&spatialRel=esriSpatialRelIntersects&outFields=COMID,StreamName,AvgPredEC&returnGeometry=true&f=geojson",
      "&geometry=", paste(round(c(lon - pad, lat - pad, lon + pad, lat + pad), 5), collapse = ",")
    )
    seg <- sf::st_read(query, quiet = TRUE)
    seg <- seg[seg$StreamName %in% "Mississippi River" & !is.na(seg$AvgPredEC), ]
    if (nrow(seg)) break
  }
  if (!nrow(seg)) return(data.frame(comid = NA_integer_, background_us_cm = NA_real_))
  pt <- sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326)
  best <- seg[which.min(as.numeric(sf::st_distance(seg, pt))), ]
  data.frame(comid = best$COMID, background_us_cm = round(best$AvgPredEC, 1))
}

snapshot_day16 <- function(cfg = day16_config()) {
  urls <- day16_urls(cfg)
  sources <- lapply(names(urls), function(f) {
    p <- file.path(cfg$cache_dir, f)
    list(
      file = f, url = urls[[f]],
      retrieved_utc = format(file.info(p)$mtime, tz = "UTC", usetz = TRUE),
      bytes = file.info(p)$size,
      sha256 = digest::digest(p, algo = "sha256", file = TRUE)
    )
  })
  usgs <- list(
    services = list(
      peaks = "https://api.waterdata.usgs.gov/ogcapi/v1/collections/peaks (parameter 00060)",
      low_flow = "https://api.waterdata.usgs.gov/ogcapi/v1/collections/daily (parameter 00060, statistic 00003)",
      conductivity = "https://www.waterqualitydata.us (CharacteristicName: Specific conductance)",
      background = paste(cfg$background_url, "(EPA Freshwater Explorer, Predicted Background Conductivity)")
    ),
    retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    dataRetrieval = as.character(utils::packageVersion("dataRetrieval")),
    files = lapply(c("gages.csv", "peaks.csv", "low-flow.csv", "conductivity.csv", "wq-sites.csv"), function(f) {
      list(file = f, sha256 = digest::digest(file.path(day16_root, f), algo = "sha256", file = TRUE))
    })
  )
  jsonlite::write_json(
    list(sources = sources, usgs = usgs),
    file.path(day16_root, "source-snapshot.json"),
    auto_unbox = TRUE, pretty = TRUE
  )
}

check_day16_snapshot <- function(cfg = day16_config()) {
  s <- jsonlite::read_json(file.path(day16_root, "source-snapshot.json"), simplifyVector = TRUE)
  if (!setequal(s$sources$file, names(day16_urls(cfg)))) stop("Snapshot sources differ from recipe")
  for (i in seq_len(nrow(s$sources))) {
    p <- file.path(cfg$cache_dir, s$sources$file[i])
    if (!file.exists(p)) stop("Missing cached source: ", p, ". Run acquire_day16().")
    if (digest::digest(p, algo = "sha256", file = TRUE) != s$sources$sha256[i]) stop("Hash mismatch: ", p)
  }
  invisible(s)
}

# One row per TRI chemical report, numbered headers stripped. Grams rows (dioxins) are dropped and counted.
read_day16_tri <- function(cfg = day16_config()) {
  wanted <- c(
    "YEAR", "TRIFD", "FACILITY NAME", "CITY", "ST", "LATITUDE", "LONGITUDE",
    "INDUSTRY SECTOR", "CHEMICAL", "FORM TYPE", "UNIT OF MEASURE", "5.3 - WATER"
  )
  files <- names(day16_tri_urls(cfg))
  rows <- lapply(files, function(f) {
    p <- file.path(cfg$cache_dir, f)
    x <- utils::read.csv(p, check.names = FALSE, colClasses = "character", na.strings = c("", "NA"), strip.white = TRUE)
    names(x) <- sub("^[0-9]+[.] ", "", names(x))
    if (!all(wanted %in% names(x)) || !nrow(x)) stop("Invalid TRI file: ", p)
    x[wanted]
  })
  d <- do.call(rbind, rows)
  if (anyNA(d$TRIFD)) stop("Missing TRI facility ID")
  if (!all(d$`UNIT OF MEASURE` %in% c("Pounds", "Grams"))) {
    stop("Unexpected TRI unit: ", paste(setdiff(unique(d$`UNIT OF MEASURE`), c("Pounds", "Grams")), collapse = ", "))
  }
  pounds <- d[d$`UNIT OF MEASURE` == "Pounds", ]
  attr(pounds, "grams_rows") <- sum(d$`UNIT OF MEASURE` == "Grams")
  pounds
}

day16_river <- function(cfg = day16_config()) {
  rivers <- sf::st_read(file.path(cfg$cache_dir, "rivers-natural-earth.geojson"), quiet = TRUE)
  river <- rivers[rivers$name %in% "Mississippi" & rivers$featurecla == "River", ]
  window <- sf::st_as_sfc(sf::st_bbox(
    cfg$window,
    crs = 4326
  ))
  river <- sf::st_intersection(sf::st_union(sf::st_geometry(river)), window)
  sf::st_transform(river, cfg$crs)
}

# Committed reductions: facility-years inside the corridor, binned to hex-years.
prepare_day16 <- function(cfg = day16_config()) {
  check_day16_snapshot(cfg)
  tri <- read_day16_tri(cfg)
  grams_rows <- attr(tri, "grams_rows")
  river <- day16_river(cfg)

  # Facility location: the latest reported coordinates, so a facility does not hop between hexes.
  tri$year <- as.integer(tri$YEAR)
  latest <- tri[!is.na(tri$LATITUDE) & !is.na(tri$LONGITUDE), ]
  latest <- latest[order(latest$TRIFD, -latest$year), ]
  latest <- latest[!duplicated(latest$TRIFD), c("TRIFD", "FACILITY NAME", "CITY", "ST", "LATITUDE", "LONGITUDE")]
  fac <- sf::st_as_sf(latest, coords = c("LONGITUDE", "LATITUDE"), crs = 4326, remove = FALSE)
  fac <- sf::st_transform(fac, cfg$crs)
  fac <- fac[as.numeric(sf::st_distance(fac, river)) <= cfg$corridor_m, ]

  hex <- sf::st_make_grid(sf::st_buffer(river, cfg$corridor_m), cellsize = cfg$hex_m, square = FALSE)
  hex <- sf::st_sf(hex_id = seq_along(hex), geometry = hex)
  in_hex <- function(pts) hex$hex_id[vapply(sf::st_intersects(pts, hex), function(i) i[1], integer(1))]
  fac$hex_id <- in_hex(fac)

  # Facility-year: water pounds summed over quantified reports. Form A and blank values are not zero.
  tri <- tri[tri$TRIFD %in% fac$TRIFD, ]
  tri$water <- suppressWarnings(as.numeric(tri$`5.3 - WATER`))
  tri$water[tri$`FORM TYPE` %in% "A"] <- NA
  crosswalk <- utils::read.csv(file.path(day16_root, "sector-groups.csv"))
  unmapped <- setdiff(stats::na.omit(unique(tri$`INDUSTRY SECTOR`)), crosswalk$source_sector)
  if (length(unmapped)) stop("Sectors missing from sector-groups.csv: ", paste(unmapped, collapse = ", "))
  fy <- tri |>
    dplyr::group_by(TRIFD, year) |>
    dplyr::summarise(
      sector = dplyr::first(stats::na.omit(`INDUSTRY SECTOR`)),
      water_lbs = if (all(is.na(water))) NA_real_ else sum(water, na.rm = TRUE),
      top_chem = if (all(is.na(water)) || max(water, na.rm = TRUE) <= 0) NA_character_ else CHEMICAL[which.max(water)],
      top_lbs = if (all(is.na(water))) NA_real_ else max(water, na.rm = TRUE),
      .groups = "drop"
    )
  fy$hex_id <- fac$hex_id[match(fy$TRIFD, fac$TRIFD)]
  fy$name <- fac$`FACILITY NAME`[match(fy$TRIFD, fac$TRIFD)]
  fy$group <- crosswalk$sector_group[match(fy$sector, crosswalk$source_sector)]
  fy$group[is.na(fy$group)] <- "Other"
  # Main sector of a hex-year: the group with the most pounds, and its share of the hex-year total.
  main <- fy[!is.na(fy$water_lbs) & fy$water_lbs > 0, ] |>
    dplyr::group_by(hex_id, year, group) |>
    dplyr::summarise(lbs = sum(water_lbs), .groups = "drop") |>
    dplyr::group_by(hex_id, year) |>
    dplyr::summarise(main_group = group[which.max(lbs)], main_share = max(lbs) / sum(lbs), .groups = "drop")

  hex_years <- fy |>
    dplyr::group_by(hex_id, year) |>
    dplyr::summarise(
      n_facilities = dplyr::n_distinct(TRIFD),
      n_quantified = sum(!is.na(water_lbs)),
      # Before water_lbs below replaces the facility values with the hex-year total.
      top_facility = if (all(is.na(water_lbs)) || max(water_lbs, na.rm = TRUE) <= 0) NA_character_ else name[which.max(water_lbs)],
      water_lbs = if (all(is.na(water_lbs))) NA_real_ else sum(water_lbs, na.rm = TRUE),
      top_chem = if (all(is.na(top_lbs)) || max(top_lbs, na.rm = TRUE) <= 0) NA_character_ else top_chem[which.max(top_lbs)],
      .groups = "drop"
    ) |>
    dplyr::left_join(main, by = c("hex_id", "year")) |>
    dplyr::arrange(hex_id, year)

  # Invasive species: NAS records with located coordinates and a year, within the corridor, binned to the same
  # hexagons. County, watershed and state centroids are dropped, as are records the database marks as failed,
  # eradicated, extirpated or stocked.
  nas <- do.call(rbind, lapply(names(day16_nas_urls(cfg)), function(f) {
    j <- jsonlite::fromJSON(file.path(cfg$cache_dir, f))
    r <- j$results
    if (!is.data.frame(r) || !nrow(r) || nrow(r) != j$count) stop("Invalid or truncated NAS file: ", f)
    data.frame(
      key = r$key, species_id = as.character(r$speciesID), species = r$commonName,
      lon = r$decimalLongitude, lat = r$decimalLatitude, year = as.integer(r$year),
      accuracy = r$latLongAccuracy, status = r$status
    )
  }))
  nas <- nas[!duplicated(nas$key) & !is.na(nas$lon) & !is.na(nas$lat) & !is.na(nas$year) &
               nas$accuracy %in% cfg$nas_accuracy & !nas$status %in% cfg$nas_drop_status, ]
  nas <- nas[nas$lon >= cfg$window[["xmin"]] & nas$lon <= cfg$window[["xmax"]] &
               nas$lat >= cfg$window[["ymin"]] & nas$lat <= cfg$window[["ymax"]], ]
  nas_pts <- sf::st_transform(sf::st_as_sf(nas, coords = c("lon", "lat"), crs = 4326), cfg$crs)
  nas <- nas[as.numeric(sf::st_distance(nas_pts, river)) <= cfg$corridor_m, ]
  nas_pts <- nas_pts[nas_pts$key %in% nas$key, ]
  nas$hex_id <- in_hex(nas_pts)
  nas$group <- unname(cfg$nas_species[nas$species_id])
  nas$species <- tolower(nas$species)
  first <- stats::aggregate(year ~ hex_id + group, nas, min)
  nas_years <- nas[nas$year %in% cfg$years, ] |>
    dplyr::count(hex_id, year, group, species, name = "n") |>
    dplyr::arrange(hex_id, year, group, dplyr::desc(n), species) |>
    dplyr::group_by(hex_id, year, group) |>
    dplyr::summarise(
      n_records = sum(n),
      detail = paste(sprintf("%s %d", species, n), collapse = ", "),
      .groups = "drop"
    )
  nas_years$first_year <- first$year[match(paste(nas_years$hex_id, nas_years$group), paste(first$hex_id, first$group))]
  hex <- hex[hex$hex_id %in% c(hex_years$hex_id, nas_years$hex_id), ]

  all_gages <- utils::read.csv(file.path(day16_root, "gages.csv"), colClasses = c(site = "character"))
  gages <- all_gages
  peaks <- utils::read.csv(file.path(day16_root, "peaks.csv"), colClasses = c(site = "character"))
  peaks <- peaks[peaks$water_year %in% cfg$years & !is.na(peaks$peak_cfs), ]
  # Gages with too few discharge peaks in the study years (stage-only or short records) are left out.
  peak_years <- table(peaks$site)
  gages <- gages[gages$site %in% names(peak_years)[peak_years >= cfg$min_peak_years], ]
  peaks <- peaks[peaks$site %in% gages$site, ]
  # Rank each gage only against its own 1987-2024 peaks, so gages of different size compare fairly.
  peaks <- peaks |>
    dplyr::group_by(site) |>
    dplyr::mutate(pctl = dplyr::percent_rank(peak_cfs), rank = rank(-peak_cfs, ties.method = "min")) |>
    dplyr::ungroup()

  # Low water: complete climatic years only, the same record-length rule as the floods, ranked within each gage
  # (pctl 1 and rank 1 = the driest year).
  low <- utils::read.csv(file.path(day16_root, "low-flow.csv"), colClasses = c(site = "character"))
  low <- low[low$climate_year %in% cfg$years & low$n_days >= cfg$low_min_days, ]
  low_years <- table(low$site)
  low <- low[low$site %in% names(low_years)[low_years >= cfg$min_peak_years], ]
  low <- low |>
    dplyr::group_by(site) |>
    dplyr::mutate(pctl = dplyr::percent_rank(-min7_cfs), rank = rank(min7_cfs, ties.method = "min")) |>
    dplyr::ungroup()
  low_gages <- all_gages[all_gages$site %in% low$site, ]

  # Conductivity: one value per site visit (median across depths), then the median visit per water year
  # (October-September, matching the peaks). QC replicates and composites are dropped; thin years are gaps.
  wq_sites <- utils::read.csv(file.path(day16_root, "wq-sites.csv"))
  sc <- utils::read.csv(file.path(day16_root, "conductivity.csv"))
  sc <- sc[sc$activity_type %in% cfg$wq_activity & !is.na(sc$value), ]
  # Rows labeled with a non-conductivity unit (or none) are dropped and counted, not relabeled.
  bad_units <- sum(!sc$unit %in% cfg$wq_units)
  sc <- sc[sc$unit %in% cfg$wq_units, ]
  members <- strsplit(wq_sites$members, ";", fixed = TRUE)
  sc$group <- rep(wq_sites$group, lengths(members))[match(sc$site, unlist(members))]
  d <- as.Date(sc$date)
  sc$water_year <- as.integer(format(d, "%Y")) + (as.integer(format(d, "%m")) >= 10)
  visits <- sc |>
    dplyr::group_by(group, site, date, water_year) |>
    dplyr::summarise(value = stats::median(value), .groups = "drop")
  conductivity <- visits[visits$water_year %in% cfg$years, ] |>
    dplyr::group_by(group, water_year) |>
    dplyr::summarise(n_visits = dplyr::n(), median_us_cm = stats::median(value), .groups = "drop") |>
    dplyr::filter(n_visits >= cfg$wq_min_visits)
  conductivity$background_us_cm <- wq_sites$background_us_cm[match(conductivity$group, wq_sites$group)]
  conductivity$ratio <- conductivity$median_us_cm / conductivity$background_us_cm

  places <- utils::read.csv(file.path(day16_root, "places.csv"))

  list(cfg = cfg, river = river, hex = hex, hex_years = hex_years, gages = gages, peaks = peaks, facilities = fac,
       grams_rows = grams_rows, low = low, low_gages = low_gages, nas = nas, nas_years = nas_years,
       wq_sites = wq_sites, conductivity = conductivity, wq_bad_units = bad_units, places = places)
}

day16_ramp <- function(prop, stops, colors) {
  pairs <- unlist(lapply(seq_along(stops), function(i) list(stops[i], colors[i])), recursive = FALSE)
  c(list("interpolate", list("linear"), list("get", prop)), pairs)
}

day16_fmt <- function(x) formatC(x, format = "f", digits = 0, big.mark = ",")

# One half of each polygon, split north-south through its centroid, with a gap of `gap` x its width between halves.
day16_half <- function(geom, side = c("east", "west"), gap = 0.05) {
  side <- match.arg(side)
  halves <- lapply(seq_along(geom), function(i) {
    bb <- sf::st_bbox(geom[[i]])
    cx <- sf::st_coordinates(sf::st_centroid(geom[[i]]))[1]
    pad <- gap * (bb[["xmax"]] - bb[["xmin"]]) / 2
    x <- if (side == "east") c(cx + pad, bb[["xmax"]]) else c(bb[["xmin"]], cx - pad)
    rect <- sf::st_polygon(list(rbind(
      c(x[1], bb[["ymin"]]), c(x[2], bb[["ymin"]]), c(x[2], bb[["ymax"]]), c(x[1], bb[["ymax"]]), c(x[1], bb[["ymin"]])
    )))
    sf::st_intersection(geom[[i]], rect)
  })
  sf::st_sfc(halves, crs = sf::st_crs(geom))
}

# One feature per site-year: the footprint copied up the cube, with base b in years since the first year.
day16_slabs <- function(prep) {
  cfg <- prep$cfg
  slab <- function(year, geometry, ...) {
    sf::st_sf(year = year, b = year - min(cfg$years), ..., geometry = geometry)
  }
  pts <- function(lon, lat) {
    sf::st_geometry(sf::st_transform(sf::st_as_sf(data.frame(lon = lon, lat = lat), coords = c("lon", "lat"), crs = 4326), cfg$crs))
  }
  # Disc radius: gage_radius_m, shrunk to 45% of the distance to the nearest other site of the same kind, so
  # neighboring columns never touch (Hastings and Prescott are 3.6 km apart). Returns the radius at each lon/lat.
  radius_at <- function(lon, lat) {
    key <- paste(lon, lat)
    u <- !duplicated(key)
    d <- matrix(as.numeric(sf::st_distance(pts(lon[u], lat[u]))), sum(u))
    diag(d) <- Inf
    r <- pmin(cfg$gage_radius_m, 0.45 * apply(d, 1, min))
    function(lon, lat) r[match(paste(lon, lat), key[u])]
  }
  gage_r <- radius_at(c(prep$gages$lon, prep$low_gages$lon), c(prep$gages$lat, prep$low_gages$lat))
  wq_used <- prep$wq_sites[prep$wq_sites$group %in% prep$conductivity$group, ]
  wq_r <- radius_at(wq_used$lon, wq_used$lat)
  discs <- function(lon, lat, r) sf::st_buffer(pts(lon, lat), r(lon, lat), nQuadSegs = 4)
  # A thin stem from the ground up to the first slab of each column (key), so a column that starts late stays tied
  # to its place. It carries that first year, so the slider shows it with the slab; columns starting in the first
  # year need none. r caps the stem radius per row (half a shrunken disc).
  stems <- function(key, year, at, r = rep(cfg$stem_radius_m, length(year))) {
    o <- order(key, year)
    i <- o[!duplicated(key[o])]
    i <- i[year[i] > min(cfg$years)]
    slab(year[i], sf::st_buffer(at[i], pmin(cfg$stem_radius_m, r[i]), nQuadSegs = 2))
  }

  # Only years with reported discharges get a slab; zero and not-quantified years are gaps in the column.
  hy <- prep$hex_years[!is.na(prep$hex_years$water_lbs) & prep$hex_years$water_lbs > 0, ]
  # Each hex-year slab is the hexagon scaled about its centre by log pounds, so columns taper as discharges fall.
  cells <- sf::st_geometry(prep$hex)[match(hy$hex_id, prep$hex$hex_id)]
  centre <- sf::st_coordinates(sf::st_centroid(cells))
  width <- cfg$tri_width[1] + diff(cfg$tri_width) * pmin(log10(pmax(hy$water_lbs, 1)) / cfg$tri_log_max, 1)
  tri <- slab(
    hy$year, sf::st_sfc(lapply(seq_along(cells), function(i) (cells[[i]] - centre[i, ]) * width[i] + centre[i, ]), crs = cfg$crs),
    group = hy$main_group,
    tip = sprintf(
      "<b>%d</b> · %d TRI facilit%s<br>Surface-water discharges: <b>%s lb</b><br>Main sector: %s (%.0f%%)<br>Largest: %s<br>Top chemical: %s",
      hy$year, hy$n_facilities, ifelse(hy$n_facilities == 1, "y", "ies"), day16_fmt(hy$water_lbs),
      hy$main_group, 100 * hy$main_share, hy$top_facility, hy$top_chem
    )
  )

  regulated <- function(site) {
    ifelse(site %in% cfg$regulated, "<br><i>Below the Old River Control Structure, which sets the flow here</i>", "")
  }
  pk <- prep$peaks
  g <- prep$gages[match(pk$site, prep$gages$site), ]
  usgs <- slab(
    pk$water_year, discs(g$lon, g$lat, gage_r),
    pctl = round(pk$pctl, 3),
    tip = sprintf(
      "<b>%s</b><br>Water year %d peak: <b>%s cfs</b> on %s<br>Rank %d of %d years since 1987 (1 = highest)%s",
      g$name, pk$water_year, day16_fmt(pk$peak_cfs), pk$peak_date, pk$rank,
      ave(pk$rank, pk$site, FUN = length), regulated(pk$site)
    )
  )

  lw <- prep$low
  lg <- prep$low_gages[match(lw$site, prep$low_gages$site), ]
  low <- slab(
    lw$climate_year, discs(lg$lon, lg$lat, gage_r),
    pctl = round(lw$pctl, 3),
    tip = sprintf(
      "<b>%s</b><br>Climatic year %d (April to March): lowest 7-day flow <b>%s cfs</b>, week ending %s%s<br>Rank %d of %d years since 1987 (1 = driest)%s",
      lg$name, lw$climate_year, day16_fmt(lw$min7_cfs), lw$min7_end,
      ifelse(lw$n_estimated > 0, sprintf(" (%d of 7 days estimated)", lw$n_estimated), ""),
      lw$rank, ave(lw$rank, lw$site, FUN = length), regulated(lw$site)
    )
  )

  wc <- prep$conductivity
  ws <- prep$wq_sites[match(wc$group, prep$wq_sites$group), ]
  wq <- slab(
    wc$water_year, discs(ws$lon, ws$lat, wq_r),
    ratio = round(wc$ratio, 3),
    tip = sprintf(
      "<b>%s</b><br>Water year %d: <b>%.1f× natural background</b><br>Median %s µS/cm over %d visits; modeled background %s µS/cm",
      wc$group, wc$water_year, wc$ratio, day16_fmt(wc$median_us_cm), wc$n_visits, day16_fmt(wc$background_us_cm)
    )
  )

  # Invasive species: each hex-year is split, invasive carp in the west half and zebra mussel in the east.
  ny <- prep$nas_years
  ncells <- sf::st_geometry(prep$hex)[match(ny$hex_id, prep$hex$hex_id)]
  ncentre <- sf::st_coordinates(sf::st_centroid(ncells))
  ncells <- sf::st_sfc(lapply(seq_along(ncells), function(i) (ncells[[i]] - ncentre[i, ]) * 0.9 + ncentre[i, ]), crs = cfg$crs)
  carp <- ny$group == "Invasive carp"
  nhalf <- ncells
  nhalf[carp] <- day16_half(ncells[carp], "west", cfg$half_gap)
  nhalf[!carp] <- day16_half(ncells[!carp], "east", cfg$half_gap)
  nas <- slab(
    ny$year, nhalf,
    group = ny$group,
    tip = sprintf(
      "<b>%d</b> · %s<br>%d USGS NAS record%s: %s<br>First reported in this hexagon: %d",
      ny$year, ny$group, ny$n_records, ifelse(ny$n_records == 1, "", "s"), ny$detail, ny$first_year
    )
  )

  # In "All", floods and low water share a gage, so each takes half of the disc.
  usgs_all <- usgs
  sf::st_geometry(usgs_all) <- day16_half(sf::st_geometry(usgs), "east", cfg$half_gap)
  low_all <- low
  sf::st_geometry(low_all) <- day16_half(sf::st_geometry(low), "west", cfg$half_gap)

  to_wgs <- function(x) {
    x <- sf::st_transform(x, 4326)
    sf::st_geometry(x) <- sf::st_as_sfc(sf::st_as_text(sf::st_geometry(x), digits = 6), crs = 4326)
    x
  }
  stem <- list(
    tri = stems(hy$hex_id, hy$year, sf::st_centroid(cells)),
    usgs = stems(pk$site, pk$water_year, pts(g$lon, g$lat), gage_r(g$lon, g$lat) / 2),
    low = stems(lw$site, lw$climate_year, pts(lg$lon, lg$lat), gage_r(lg$lon, lg$lat) / 2),
    wq = stems(wc$group, wc$water_year, pts(ws$lon, ws$lat), wq_r(ws$lon, ws$lat) / 2),
    # Narrower than the industry stems on the same hexagon centres, so the two never draw one cylinder in "All".
    nas = stems(ny$hex_id, ny$year, sf::st_centroid(ncells), rep(0.6 * cfg$stem_radius_m, nrow(ny)))
  )
  names(stem) <- paste0(names(stem), "-stem")
  # In "All", floods and low-water stems split like their slabs, so a gage with both never draws two in one place.
  stem$`usgs-stem-all` <- stem$`usgs-stem`
  sf::st_geometry(stem$`usgs-stem-all`) <- day16_half(sf::st_geometry(stem$`usgs-stem`), "east", cfg$half_gap)
  stem$`low-stem-all` <- stem$`low-stem`
  sf::st_geometry(stem$`low-stem-all`) <- day16_half(sf::st_geometry(stem$`low-stem`), "west", cfg$half_gap)
  places <- sf::st_as_sf(prep$places, coords = c("lon", "lat"), crs = 4326)
  c(
    lapply(c(list(tri = tri, usgs = usgs, `usgs-all` = usgs_all, low = low, `low-all` = low_all, wq = wq, nas = nas), stem), to_wgs),
    list(river = sf::st_transform(sf::st_sf(geometry = prep$river), 4326), places = places)
  )
}

# fill-extrusion height in metres for a property counted in years of the cube, plus `add` years, scaled by zoom.
day16_height <- function(prop, cfg, add = 0) {
  z <- as.numeric(names(cfg$metres_per_year))
  value <- if (add == 0) list("get", prop) else list("+", list("get", prop), add)
  stops <- unlist(lapply(seq_along(z), function(i) list(z[i], list("*", cfg$metres_per_year[[i]], value))), recursive = FALSE)
  c(list("interpolate", list("linear"), list("zoom")), stops)
}

# The year-stacked extrusion layers: one per ledger, and an "-all" copy of each, each with its stems. Alone, a slab
# fills its year; in "All", each ledger takes its own plate within the year (floods and low water share one, split in
# halves), so no two ledgers share a surface. Stems rise to the base of the ledger's first slab. Only Industry shows
# on load.
day16_extrusions <- function(map, colors, sources, tip_style, cfg) {
  plates <- c(tri = 1, usgs = 2, low = 2, wq = 3, nas = 4)
  step <- cfg$slab / max(plates)
  for (set in c("", "-all")) {
    for (k in names(colors)) {
      id <- paste0(k, set)
      base <- if (set == "") 0 else (plates[[k]] - 1) * step
      top <- if (set == "") cfg$slab else base + step * 0.85
      map <- mapgl::add_fill_extrusion_layer(
        map, id = id, source = sources[[id]],
        fill_extrusion_color = colors[[k]],
        fill_extrusion_base = day16_height("b", cfg, base),
        fill_extrusion_height = day16_height("b", cfg, top),
        fill_extrusion_opacity = 0.92,
        visibility = if (id == "tri") "visible" else "none",
        tooltip = "tip", tooltip_style = tip_style
      )
      map <- mapgl::add_fill_extrusion_layer(
        map, id = paste0(k, "-stem", set), source = sources[[paste0(k, "-stem", set)]],
        fill_extrusion_color = cfg$stem_color,
        fill_extrusion_base = 0,
        fill_extrusion_height = day16_height("b", cfg, base),
        fill_extrusion_opacity = cfg$stem_opacity,
        visibility = if (id == "tri") "visible" else "none"
      )
    }
  }
  map
}

# One legend per extrusion layer (a legend follows a single layer's visibility), so each set shows its own. In
# "All" the five legends stack too tall for a laptop screen, so they collapse to their titles, and the two
# category legends start collapsed.
day16_legends <- function(map, style, cfg) {
  ramp <- function(map, title, values, colors, k, set) {
    mapgl::add_legend(
      map, title, values = values, colors = colors, type = "continuous", position = "bottom-right", add = TRUE,
      style = style, layer_id = paste0(k, set), unique_id = paste0("legend-", k, set), collapsible = set != ""
    )
  }
  groups <- function(map, title, groups, k, set) {
    mapgl::add_legend(
      map, title, values = names(groups), colors = unname(groups),
      interactive = TRUE, filter_column = "group", filter_values = names(groups),
      type = "categorical", position = "bottom-right", add = TRUE, style = style,
      layer_id = paste0(k, set), unique_id = paste0("legend-", k, set),
      collapsible = set != "", collapsed = set != ""
    )
  }
  for (set in c("", "-all")) {
    map <- map |>
      ramp("Flood peak, rank at gage", c("lowest", "", "median", "", "highest"), cfg$gage_ramp, "usgs", set) |>
      ramp("Low flow, rank at gage", c("wettest", "", "median", "", "driest"), cfg$low_ramp, "low", set) |>
      ramp("Conductivity × natural", sprintf("%.1f×", cfg$wq_stops), cfg$wq_ramp, "wq", set) |>
      groups("Invasive species records", cfg$nas_groups, "nas", set) |>
      groups("Main sector to surface water", cfg$tri_groups, "tri", set)
  }
  map
}

build_day16_widget <- function(prep) {
  cfg <- prep$cfg
  s <- day16_slabs(prep)
  tip_style <- mapgl::tooltip_style(
    background_color = "#0f151b", text_color = cfg$ink, border_color = "#ffffff24",
    border_radius = 8, font_size = 12, padding = 9, max_width = 300
  )
  legend <- mapgl::legend_style(
    background_color = "#0f151b", background_opacity = 0.93, border_color = "#ffffff24", border_width = 1,
    border_radius = 10, text_color = "#c9d3db", title_color = cfg$ink, title_size = 13, text_size = 12
  )
  match_group <- function(groups) {
    c(
      list("match", list("get", "group")),
      unlist(lapply(names(groups), function(g) list(g, groups[[g]])), recursive = FALSE),
      list(groups[[length(groups)]])
    )
  }
  colors <- list(
    tri = match_group(cfg$tri_groups),
    usgs = day16_ramp("pctl", cfg$gage_stops, cfg$gage_ramp),
    low = day16_ramp("pctl", cfg$gage_stops, cfg$low_ramp),
    wq = day16_ramp("ratio", cfg$wq_stops, cfg$wq_ramp),
    nas = match_group(cfg$nas_groups)
  )
  # Each ledger is drawn twice: alone (its own switch entry) and in the "All" set, so no layer belongs to two entries
  # of the one-at-a-time switch.
  ledgers <- names(colors)
  ids <- c(ledgers, paste0(ledgers, "-all"))
  stem_ids <- c(paste0(ledgers, "-stem"), paste0(ledgers, "-stem-all"))
  # Alone and "All" copies share a source, except floods and low water (slabs and stems), which are split in "All".
  sources <- setNames(paste0(sub("-all$", "", c(ids, stem_ids)), "-src"), c(ids, stem_ids))
  split <- c("usgs-all", "low-all", "usgs-stem-all", "low-stem-all")
  sources[split] <- paste0(split, "-src")
  orgs <- unique(sub("^USGS-.*", "USGS", prep$wq_sites$org[prep$wq_sites$group %in% prep$conductivity$group]))
  wq_credit <- paste(ifelse(orgs %in% names(cfg$wq_org_names), cfg$wq_org_names[orgs], orgs), collapse = ", ")
  panel <- sprintf(
    '<div style="width:290px;background:#0f151bee;color:%s;border:1px solid #ffffff24;border-radius:10px;
      padding:13px 15px;font:13px/1.45 system-ui,sans-serif">
      <div style="font-size:10.5px;letter-spacing:.09em;text-transform:uppercase;color:%s;font-weight:600">
        30DayMapChallenge · Day 16</div>
      <details><summary style="cursor:pointer;font-size:21px;font-weight:700;line-height:1.15;margin:3px 0 7px;color:%s"
      title="Show or hide the description">The river\'s ledger</summary>
      <div style="color:#c9d3db">Five ledgers of one river, switched below (or all at once). Each column stacks years,
      1987 at the ground to 2024 at the top; gaps are years with nothing on record.
      <b style="color:#ff7a45">Industry</b>: TRI facilities, colored by the sector discharging the most to surface
      water; wider slabs, more pounds. <b style="color:#7fd3ea">Floods</b> and
      <b style="color:#e8a95c">low water</b>: USGS gages, brighter in bigger flood years and in drier years.
      <b style="color:#b57ee0">Conductivity</b>: how many times its modeled natural level the river ran.
      <b style="color:#b8f53a">Invasives</b>: years with reports of invasive carp or zebra mussel (records, not
      abundance).</div>
      <div style="color:%s;font-size:11px;margin-top:8px">Data: USGS Water Data API (annual peaks, daily flow); USGS
      Nonindigenous Aquatic Species database; EPA Toxics Release Inventory 1987–2024; Water Quality Portal (%s); EPA
      Freshwater Explorer background conductivity. %s.</div></details></div>',
    cfg$ink, cfg$muted, cfg$ink, cfg$muted, wq_credit, cfg$label
  )
  map <- mapgl::maplibre(
    style = mapgl::carto_style("dark-matter-no-labels"), projection = "mercator", maxPitch = 80,
    center = cfg$camera$center, zoom = cfg$camera$zoom,
    pitch = cfg$camera$pitch, bearing = cfg$camera$bearing
  ) |>
    mapgl::add_line_layer(
      id = "river", source = s$river,
      line_color = "#3d7ea6", line_width = 2.2, line_opacity = 0.8
    )
  for (src in unique(sources)) map <- mapgl::add_source(map, src, s[[sub("-src$", "", src)]])
  map |>
    day16_extrusions(colors, sources, tip_style, cfg) |>
    # Place names stand upright on the ground just below each city, above the columns in draw order.
    mapgl::add_symbol_layer(
      id = "places", source = s$places, text_field = mapgl::get_column("name"),
      text_font = c("Montserrat Medium", "Open Sans Regular", "Noto Sans Regular", "Noto Sans CJK JP Regular"),
      text_size = 12, text_color = "#d5dde4", text_halo_color = "#0b0f14", text_halo_width = 1.4,
      text_anchor = "top", text_offset = c(0, 0.7), text_pitch_alignment = "viewport"
    ) |>
    mapgl::add_slider_control(
      layers = c(ids, stem_ids), property = "year", values = cfg$years,
      mode = "cumulative", initial_value = max(cfg$years),
      play_button = TRUE, animation_duration = 350, loop = TRUE,
      title = "Year", position = "bottom-left",
      background_color = "#0f151b", text_color = cfg$ink, accent_color = "#7fd3ea"
    ) |>
    day16_legends(legend, cfg) |>
    mapgl::add_control(panel, position = "top-left") |>
    mapgl::add_navigation_control(visualize_pitch = TRUE) |>
    mapgl::add_layers_control(
      layers = list(
        Industry = c("tri", "tri-stem"), Floods = c("usgs", "usgs-stem"), `Low water` = c("low", "low-stem"),
        Conductivity = c("wq", "wq-stem"), Invasives = c("nas", "nas-stem"),
        `All five` = c(paste0(ledgers, "-all"), paste0(ledgers, "-stem-all"))
      ),
      mode = "single", collapsible = FALSE, position = "top-left",
      background_color = "#0f151b", active_color = "#2a6f9e", hover_color = "#1b2630",
      active_text_color = cfg$ink, inactive_text_color = cfg$muted
    )
}

render_day16 <- function(cfg = day16_config()) {
  prep <- prepare_day16(cfg)
  build_day16_widget(prep)
}
