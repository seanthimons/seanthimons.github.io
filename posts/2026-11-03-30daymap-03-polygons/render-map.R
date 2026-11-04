#!/usr/bin/env Rscript
if (dir.exists('.R-library')) .libPaths(c(normalizePath('.R-library'), .libPaths()))
day03_root <- 'posts/2026-11-03-30daymap-03-polygons'
source(file.path(day03_root, 'acquire-data.R'))
day03_config <- function() list(
  crs = 26916L, bounds = c(xmin = -84.2, ymin = 41.0, xmax = -82.6, ymax = 41.7),
  background = '#14232B', ink = '#E7E1D4', muted = '#B2BDBD', lead = '#16252B',
  soil_colors = c(Aqualfs = '#6FA9AF', Udalfs = '#D3AE6D', Aquolls = '#B184B0',
    Aquepts = '#7FA882', Psamments = '#DE896E', Udolls = '#B4BF73',
    'Other suborders' = '#7A8DB9', 'Unclassified / nonsoil' = '#647079'),
  rock_angles = c(Carbonate = NA_real_, 'Carbonate mixture' = 45,
    'Shale / clastic' = 0, 'Mixed clastic / carbonate' = 90))

read_sda_table <- function(path) {
  x <- jsonlite::fromJSON(path)$Table
  if (is.null(x) || nrow(x) < 2) stop('Empty SDA table: ', path)
  d <- as.data.frame(x[-1, , drop = FALSE], stringsAsFactors = FALSE)
  names(d) <- x[1, ]; d
}

snapshot_day03 <- function(cache_dir) {
  files <- sort(list.files(cache_dir, pattern = '\\.(json|sql|txt)$', full.names = TRUE))
  records <- lapply(files, function(f) list(file = basename(f), bytes = file.info(f)$size,
    retrieved_utc = format(file.info(f)$mtime, tz = 'UTC', usetz = TRUE),
    sha256 = digest::digest(f, algo = 'sha256', file = TRUE)))
  jsonlite::write_json(list(sources = records,
    sda_endpoint = 'https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest',
    bedrock_query = readLines(file.path(cache_dir, 'bedrock-query-url.txt'), warn = FALSE),
    note = 'Raw payload fingerprints. SDA and ODNR services are mutable; retain original cache for exact reproduction.'),
    file.path(day03_root, 'source-snapshot.json'), pretty = TRUE, auto_unbox = TRUE)
}

check_day03_snapshot <- function(cache_dir) {
  path <- file.path(day03_root, 'source-snapshot.json')
  if (!file.exists(path)) stop('Missing reviewed source snapshot')
  records <- jsonlite::fromJSON(path)$sources
  for (i in seq_len(nrow(records))) {
    f <- file.path(cache_dir, records$file[i])
    if (!file.exists(f) || !identical(digest::digest(f, algo = 'sha256', file = TRUE), records$sha256[i]))
      stop('Missing or changed source snapshot: ', f)
  }
  actual <- sort(basename(list.files(cache_dir, pattern = '^soil-[0-9]+\\.json$')))
  expected <- sort(records$file[grepl('^soil-[0-9]+\\.json$', records$file)])
  if (!identical(actual, expected)) stop('Unexpected soil pages; review the source snapshot')
}

prepare_day03 <- function(cache_dir) {
  check_day03_snapshot(cache_dir)
  cfg <- day03_config()
  query_url <- readLines(file.path(cache_dir,'bedrock-query-url.txt'),warn=FALSE)
  envelope <- as.numeric(strsplit(httr::parse_url(query_url)$query$geometry,',',fixed=TRUE)[[1]])
  if(length(envelope)!=4L || any(!is.finite(envelope)) ||
     envelope[1]>cfg$bounds['xmin'] || envelope[2]>cfg$bounds['ymin'] ||
     envelope[3]<cfg$bounds['xmax'] || envelope[4]<cfg$bounds['ymax'])
    stop('Bedrock acquisition envelope does not enclose the study window')
  message('Reading and validating soil source pages')
  # Project to meters before clipping, intersecting, and measuring areas.
  roi <- sf::st_transform(sf::st_as_sfc(sf::st_bbox(cfg$bounds, crs = 4326)), cfg$crs)
  pages <- sort(list.files(cache_dir, pattern = '^soil-[0-9]+\\.json$', full.names = TRUE))
  if (!length(pages)) stop('Missing soil geometry pages')
  rows <- do.call(rbind, lapply(pages, read_sda_table))
  count <- as.integer(read_sda_table(file.path(cache_dir, 'count.json'))$polygons)
  if (nrow(rows) != count || anyDuplicated(rows$mupolygonkey)) stop('Incomplete or duplicate soil geometry')
  components <- read_sda_table(file.path(cache_dir, 'components.json'))
  components$comppct_r <- as.numeric(components$comppct_r)
  # Largest representative component percentage; numeric component-key tie break.
  components <- components[order(components$mukey, -components$comppct_r,
    as.numeric(components$cokey), na.last = TRUE), ]
  ties <- tapply(components$comppct_r, components$mukey,
    function(x) {x <- x[is.finite(x)]; length(x) > 1 && sum(x == max(x)) > 1})
  dominant <- components[!duplicated(components$mukey), ]
  i <- match(rows$mukey, dominant$mukey)
  if (anyNA(i)) stop('Unmatched soil mapunit attributes')
  soils <- sf::st_as_sf(cbind(rows[c('mupolygonkey', 'mukey')],
    dominant[i, c('musym', 'muname', 'cokey', 'compname', 'comppct_r', 'taxorder', 'taxsuborder')]),
    geometry = sf::st_as_sfc(rows$wkt, crs = 4326))
  message('Projecting and clipping ',nrow(soils),' soil polygons')
  soils <- sf::st_transform(soils, cfg$crs)
  invalid_soils <- sum(!sf::st_is_valid(soils))
  if (invalid_soils) soils <- sf::st_make_valid(soils)
  soils <- suppressWarnings(sf::st_intersection(soils, roi))
  soils <- soils[as.numeric(sf::st_area(soils)) > 0, ]
  known <- names(cfg$soil_colors)[1:6]
  soils$soil_group <- ifelse(is.na(soils$taxsuborder) | soils$taxsuborder == '',
    'Unclassified / nonsoil', ifelse(soils$taxsuborder %in% known,
    soils$taxsuborder, 'Other suborders'))
  if (any(!is.finite(soils$comppct_r))) soils$soil_group[!is.finite(soils$comppct_r)] <- 'Unclassified / nonsoil'
  rock <- sf::st_read(file.path(cache_dir, 'bedrock.geojson'), quiet = TRUE)
  if (anyDuplicated(rock$OBJECTID)) stop('Duplicate bedrock features')
  metadata <- jsonlite::fromJSON(file.path(cache_dir, 'bedrock-layer.json'))
  if (nrow(rock) >= metadata$maxRecordCount) stop('Bedrock query may be truncated')
  rock <- sf::st_transform(rock, cfg$crs)
  invalid_rock <- sum(!sf::st_is_valid(rock))
  if (invalid_rock) rock <- sf::st_make_valid(rock)
  rock <- suppressWarnings(sf::st_intersection(rock, roi))
  groups <- utils::read.csv(file.path(day03_root, 'rock-groups.csv'), stringsAsFactors = FALSE)
  rock$rock_group <- groups$rock_group[match(rock$UNIT_LITH, groups$source_lithology)]
  if (anyNA(rock$rock_group)) stop('Unclassified bedrock lithology')
  message('Intersecting soils and bedrock')
  mosaic <- suppressWarnings(sf::st_intersection(soils, rock[c('OBJECTID', 'UNIT_CODE', 'UNIT_LITH', 'rock_group')]))
  mosaic <- sf::st_collection_extract(mosaic, 'POLYGON', warn = FALSE)
  mosaic$area_km2 <- as.numeric(sf::st_area(mosaic)) / 1e6
  mosaic <- mosaic[mosaic$area_km2 > 0, ]
  if (!nrow(mosaic) || any(!sf::st_is_valid(mosaic))) stop('Empty or invalid intersection')
  area <- stats::aggregate(area_km2 ~ soil_group + rock_group, sf::st_drop_geometry(mosaic), sum)
  # Overlapping bedrock units would count a soil area more than once.
  soil_area <- sum(as.numeric(sf::st_area(soils))) / 1e6
  overlap_area <- sum(mosaic$area_km2)
  covered <- as.numeric(sf::st_area(sf::st_union(sf::st_geometry(mosaic)))) / 1e6
  if (abs(overlap_area - covered) > .01) stop('Overlapping intersections exceed 0.01 square km')
  message(nrow(mosaic), ' intersections; ', round(overlap_area), ' square km')
  list(mosaic = mosaic, rock = rock, roi = roi, area = area,
    source_count = count, clipped_soil_count = nrow(soils), soil_area_km2 = soil_area,
    intersection_area_km2 = overlap_area, covered_area_km2 = covered,
    invalid_inputs_repaired = c(soil = invalid_soils, bedrock = invalid_rock),
    tied_dominant_mapunits = sum(ties), dominant_components = dominant)
}

# Projected hatch lines are intersected with the dissolved bedrock classes. This
# respects holes and crosses soil edges continuously; no texture is hand-painted.
day03_hatches <- function(geometry, angle, spacing = 2200) {
  bb <- sf::st_bbox(geometry)
  center <- c(mean(bb[c('xmin', 'xmax')]), mean(bb[c('ymin', 'ymax')]))
  span <- sqrt((bb['xmax'] - bb['xmin'])^2 + (bb['ymax'] - bb['ymin'])^2) + spacing
  theta <- angle * pi / 180; direction <- c(cos(theta), sin(theta))
  normal <- c(-sin(theta), cos(theta))
  lines <- lapply(seq(-span, span, by = spacing), function(k) {
    p <- center + normal * k
    sf::st_linestring(rbind(p - direction * span, p + direction * span))
  })
  suppressWarnings(sf::st_intersection(sf::st_sfc(lines, crs = sf::st_crs(geometry)), geometry))
}

draw_day03 <- function(data, variant = 'earth') {
  cfg <- day03_config(); m <- data$mosaic
  colors <- cfg$soil_colors
  if (variant == 'earth') colors[] <- c('#649596','#D0AC75','#987C9A','#82986E','#C78869','#B6B078','#7D8FA6','#657077')
  par(bg = cfg$background, fg = cfg$ink, col.axis = cfg$muted, family = 'sans', xaxs = 'i', yaxs = 'i')
  panel <- function(fig, new = TRUE) par(fig = fig, mar = rep(0, 4), new = new)
  panel(c(.06, .96, .90, .99), FALSE); plot.new(); plot.window(c(0, 1), c(0, 1))
  text(0, .83, '03 / POLYGONS     •     NORTHWEST OHIO', adj = 0, cex = .85, col = cfg$muted)
  text(0, .43, 'Does the soil remember the rock?', adj = 0, cex = 1.9, font = 2)
  text(0, .12, 'SSURGO soil suborders × mapped bedrock lithology  /  Great Black Swamp region', adj = 0, cex = .95)
  panel(c(.06, .96, .34, .88))
  plot(sf::st_geometry(data$roi), col = '#243C48', border = NA, axes = FALSE, asp = 1)
  plot(sf::st_geometry(m), col = unname(colors[m$soil_group]), border = cfg$lead, lwd = .12, add = TRUE)
  for (name in names(cfg$rock_angles)) {
    angle <- cfg$rock_angles[[name]]
    if (!is.finite(angle)) next
    r <- data$rock[data$rock$rock_group == name, ]
    if (!nrow(r)) next
    hatch <- day03_hatches(sf::st_union(sf::st_geometry(r)), angle)
    plot(hatch, add = TRUE, col = '#18222B80', lwd = .65)
  }
  # Geological contacts remain visible over the fine soil mosaic.
  plot(sf::st_geometry(data$rock), add = TRUE, col = NA, border = '#E9DFCB90', lwd = 1.25)
  places <- data.frame(name = c('Bowling Green', 'Toledo', 'Fremont', 'Findlay'),
    lon = c(-83.6500, -83.5552, -83.1219, -83.6499), lat = c(41.3748,41.6528,41.3503,41.0442))
  places <- sf::st_transform(sf::st_as_sf(places, coords = c('lon','lat'), crs = 4326), cfg$crs)
  xy <- sf::st_coordinates(places)
  points(xy, pch = 21, bg = cfg$ink, col = cfg$background, cex = .65)
  text(xy[,1]+1800, xy[,2]+1000, places$name, adj = 0, cex = .72, col = cfg$ink,
    font = 2)
  # Metric scale bar, located within the lower-right portion of the frame.
  bb <- sf::st_bbox(data$roi); x <- bb['xmax'] - 32000; y <- bb['ymin'] + 5500
  segments(x, y, x + 20000, y, col = cfg$ink, lwd = 2)
  segments(c(x,x+10000,x+20000),y-650,c(x,x+10000,x+20000),y+650,col=cfg$ink)
  text(c(x,x+20000),y+2200,c('0','20 km'),col=cfg$ink,cex=.65)
  panel(c(.06, .96, .05, .32)); plot.new(); plot.window(c(0, 1), c(0, 1))
  text(0, .97, 'COLOR = SOIL SUBORDER OF LARGEST COMPONENT', adj = 0, cex = .8, col = cfg$muted)
  text(0, .88, 'TEXTURE = BEDROCK GROUP', adj = 0, cex = .8, col = cfg$muted)
  soil_names <- names(colors); rock_names <- names(cfg$rock_angles)
  x0 <- .25; cellw <- .09; cellh <- .115
  for (j in seq_along(soil_names)) {
    x <- x0 + (j-1)*cellw
    text(x+cellw*.42, .79, switch(soil_names[j], 'Other suborders'='Other',
      'Unclassified / nonsoil'='Unclassified',soil_names[j]),cex=.65)
    for (i in seq_along(rock_names)) {
      y <- .67 - (i-1)*cellh
      present <- any(data$area$soil_group == soil_names[j] & data$area$rock_group == rock_names[i])
      if (!present) {
        text(x+cellw*.42,y,'—',cex=.7,col=cfg$muted)
        next
      }
      rect(x,y-cellh*.3,x+cellw*.84,y+cellh*.3,col=colors[j],border=cfg$lead)
      angle <- cfg$rock_angles[i]
      if (is.finite(angle)) {
        # Legend examples use base R polygon hatching with the same orientations.
        polygon(c(x,x+cellw*.84,x+cellw*.84,x),c(y-cellh*.3,y-cellh*.3,y+cellh*.3,y+cellh*.3),
          density=10,angle=angle,col='#18222BA0',border=NA)
      }
    }
  }
  for (i in seq_along(rock_names)) text(0, .67-(i-1)*cellh, rock_names[i], adj=0,cex=.72)
  text(0,.15,'Fine dark edges: soil units · Pale contacts: bedrock units · Blue ground: no joint coverage · —: absent combination',adj=0,cex=.7,col=cfg$muted)
  text(0,.055,'Soil components are mixtures within map units. Buried bedrock is not necessarily soil parent material.',adj=0,cex=.72,col=cfg$muted)
  panel(c(.06,.96,.005,.04));plot.new();plot.window(c(0,1),c(0,1))
  text(0,.65,'USDA–NRCS SSURGO + Ohio Geological Survey  /  NAD83 UTM 16N  /  #30DayMapChallenge',adj=0,cex=.7,col=cfg$muted)
  text(0,.08,'Bedrock source scale 1:500,000; intersection edges do not increase geological precision.  /  Sean Thimons',adj=0,cex=.7,col=cfg$muted)
}

render_day03 <- function(cache_dir = 'data/30daymap/2026/day03',
  output_dir = file.path(day03_root,'artifacts'), rebuild = FALSE) {
  stopifnot(requireNamespace('sf', quietly=TRUE),requireNamespace('digest',quietly=TRUE))
  check_day03_snapshot(cache_dir)
  derived <- file.path(cache_dir,'intersection.rds')
  snapshot_hash <- digest::digest(file.path(day03_root,'source-snapshot.json'),algo='sha256',file=TRUE)
  code_hash <- digest::digest(list(body(prepare_day03),body(read_sda_table),body(day03_config)),algo='sha256')
  group_hash <- digest::digest(file.path(day03_root,'rock-groups.csv'),algo='sha256',file=TRUE)
  signature <- c(snapshot_hash,code_hash,group_hash)
  cached <- if(file.exists(derived) && !rebuild) readRDS(derived) else NULL
  if(is.null(cached) || !identical(cached$signature,signature)) {
    data <- prepare_day03(cache_dir);saveRDS(list(signature=signature,data=data),derived)
  } else data <- cached$data
  dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
  for(variant in c('jewel','earth')) {
    grDevices::png(file.path(output_dir,paste0('day03-soil-rock-',variant,'.png')),
      width=3000,height=2500,res=220,type='cairo')
    tryCatch(draw_day03(data,variant),finally=grDevices::dev.off())
  }
  grDevices::cairo_pdf(file.path(output_dir,'day03-soil-rock.pdf'),width=3000/220,height=2500/220)
  tryCatch(draw_day03(data),finally=grDevices::dev.off())
  utils::write.csv(data$area,file.path(output_dir,'intersection-area-km2.csv'),row.names=FALSE)
  report <- c(data[c('source_count','clipped_soil_count','soil_area_km2',
    'intersection_area_km2','covered_area_km2','invalid_inputs_repaired','tied_dominant_mapunits')],
    list(intersection_features=nrow(data$mosaic), config=day03_config(),
      input_snapshot_sha256=snapshot_hash, package_versions=vapply(c('sf','jsonlite','digest','httr'),
      function(p)as.character(utils::packageVersion(p)),character(1)),
      spatial_libraries=sf::sf_extSoftVersion(),session=capture.output(sessionInfo())))
  writeLines(sub('[[:blank:]]+$','',capture.output(dput(report))),
    file.path(output_dir,'provenance.R'))
  invisible(report)
}
if(sys.nframe()==0L) {
  args <- commandArgs(TRUE)
  if('--download' %in% args) acquire_day03()
  if('--snapshot' %in% args) snapshot_day03('data/30daymap/2026/day03')
  render_day03(rebuild='--rebuild' %in% args)
}
