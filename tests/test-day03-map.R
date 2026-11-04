# Run from repository root after the Day03 map and Quarto render.
source('posts/2026-11-03-30daymap-03-polygons/render-map.R')
cache <- 'data/30daymap/2026/day03'
check_day03_snapshot(cache)
envelope <- as.numeric(strsplit(httr::parse_url(readLines(file.path(cache,
  'bedrock-query-url.txt'),warn=FALSE))$query$geometry,',',fixed=TRUE)[[1]])
roi_bounds <- day03_config()$bounds
stopifnot(envelope[1] <= roi_bounds['xmin'], envelope[2] <= roi_bounds['ymin'],
  envelope[3] >= roi_bounds['xmax'], envelope[4] >= roi_bounds['ymax'])
x <- readRDS(file.path(cache,'intersection.rds'))$data
p <- dget(file.path(day03_root,'artifacts/provenance.R'))
stopifnot(x$source_count == 79494L, nrow(x$mosaic) > 79494L,
  sf::st_crs(x$mosaic)$epsg == 26916L, all(sf::st_is_valid(x$mosaic)),
  all(x$mosaic$area_km2 > 0),
  all(x$mosaic$soil_group %in% names(day03_config()$soil_colors)),
  all(x$mosaic$rock_group %in% names(day03_config()$rock_angles)),
  abs(x$intersection_area_km2 - x$covered_area_km2) < .01,
  x$intersection_area_km2 <= x$soil_area_km2 + .01)
# Independently check that selected component percentages are maxima for their units.
components <- read_sda_table(file.path(cache,'components.json'))
components$comppct_r <- as.numeric(components$comppct_r)
maxima <- tapply(components$comppct_r,components$mukey,function(v) {
  v <- v[is.finite(v)]; if(length(v)) max(v) else NA_real_
})
d <- x$dominant_components
stopifnot(isTRUE(all.equal(as.numeric(maxima[d$mukey]),d$comppct_r,check.attributes=FALSE)))
# Interior samples of the resulting pieces must lie in their attributed rock units.
set.seed(3)
sample <- x$mosaic[sample.int(nrow(x$mosaic),min(200,nrow(x$mosaic))),]
points <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(sample)))
contained <- sf::st_covered_by(points,x$rock)
stopifnot(all(vapply(seq_along(contained),function(i)
  sample$OBJECTID[i] %in% x$rock$OBJECTID[contained[[i]]],logical(1))))
area <- read.csv(file.path(day03_root,'artifacts/intersection-area-km2.csv'))
stopifnot(abs(sum(area$area_km2) - x$intersection_area_km2) < 1e-6)
# A changed source must fail before geometry processing or a cached render.
local({
  scratch <- tempfile();dir.create(scratch);on.exit(unlink(scratch,recursive=TRUE))
  records <- jsonlite::fromJSON(file.path(day03_root,'source-snapshot.json'))$sources
  for(f in records$file) {
    if(f=='count.json')writeLines('{}',file.path(scratch,f)) else
      stopifnot(file.symlink(normalizePath(file.path(cache,f)),file.path(scratch,f)))
  }
  failure<-tryCatch({check_day03_snapshot(scratch);NULL},error=identity)
  stopifnot(inherits(failure,'error'),grepl('changed source',conditionMessage(failure)))
})
local({
  con<-file(file.path(day03_root,'artifacts/day03-soil-rock-earth.png'),'rb');on.exit(close(con))
  stopifnot(identical(readBin(con,'raw',8),as.raw(c(137,80,78,71,13,10,26,10))))
  seek(con,16);stopifnot(identical(readBin(con,'integer',2,size=4,endian='big'),c(3000L,2500L)))
})
freeze <- jsonlite::fromJSON(paste0('_freeze/posts/2026-11-03-30daymap-03-polygons/',
  '2026-11-03-30daymap-03-polygons/execute-results/html.json'))
stopifnot(grepl('day03-soil-rock-earth.png',freeze$result$markdown,fixed=TRUE),
  grepl('stained-glass mosaic',freeze$result$markdown,ignore.case=TRUE))
cat('PASS: source completeness, dominant components, geometry, rock attribution, areas, source-change rejection, PNG and freeze\n')
