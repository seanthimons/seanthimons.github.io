# Native R source acquisition. No requests are made by the post render.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day03_wkt <- function() 'POLYGON((-84.2 41.0,-82.6 41.0,-82.6 41.7,-84.2 41.7,-84.2 41.0))'
day03_sda <- function(query, path) {
  if (!file.exists(path)) {
    r <- httr::RETRY('POST', 'https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest',
      body = list(query = query, format = 'JSON+COLUMNNAME'), encode = 'json',
      httr::timeout(180), times = 3, quiet = TRUE)
    httr::stop_for_status(r)
    body <- httr::content(r, 'text', encoding = 'UTF-8')
    j <- jsonlite::fromJSON(body)
    if (is.null(j$Table)) stop('SDA response has no table: ', substr(body, 1, 300))
    writeLines(body, path)
    writeLines(query, sub('json$', 'sql', path))
  }
  jsonlite::fromJSON(path)$Table
}
acquire_day03 <- function(cache_dir = 'data/30daymap/2026/day03') {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  base <- 'https://gis2.ohiodnr.gov/arcgis/rest/services/DNR_Services/SUBSURFACE/MapServer/5'
  params <- list(f = 'geojson', where = '1=1', geometry = '-84.8,40.5,-82.5,41.8',
    geometryType = 'esriGeometryEnvelope', inSR = 4326,
    spatialRel = 'esriSpatialRelIntersects',
    outFields = 'OBJECTID,UNIT_CODE,UNIT_NAME,UNIT_LITH,UNIT_DESCRIPTION', outSR = 4326)
  # Query slightly beyond the display window; the final clip is done in sf.
  if (!file.exists(file.path(cache_dir, 'bedrock.geojson'))) {
    r <- httr::GET(paste0(base, '/query'), query = params, httr::timeout(180))
    httr::stop_for_status(r)
    body <- httr::content(r, 'text', encoding = 'UTF-8')
    j <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    if (is.null(j$features) || isTRUE(j$exceededTransferLimit)) stop('Invalid/truncated bedrock result')
    writeBin(charToRaw(body), file.path(cache_dir, 'bedrock.geojson'))
    writeLines(r$url, file.path(cache_dir, 'bedrock-query-url.txt'))
  }
  if (!file.exists(file.path(cache_dir, 'bedrock-layer.json'))) {
    r <- httr::GET(base, query = list(f = 'pjson'), httr::timeout(120)); httr::stop_for_status(r)
    writeBin(charToRaw(httr::content(r, 'text', encoding = 'UTF-8')), file.path(cache_dir, 'bedrock-layer.json'))
  }
  wkt <- day03_wkt()
  q <- sprintf(paste0('SELECT m.mukey,m.musym,m.muname,c.cokey,c.compname,c.comppct_r,',
    'c.majcompflag,c.taxorder,c.taxsuborder,c.taxgrtgroup,c.taxsubgrp,c.taxclname ',
    'FROM mapunit m LEFT JOIN component c ON m.mukey=c.mukey ',
    "WHERE m.mukey IN (SELECT mukey FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('%s')) ",
    'ORDER BY m.mukey,c.comppct_r DESC,c.cokey'), wkt)
  day03_sda(q, file.path(cache_dir, 'components.json'))
  q <- sprintf(paste0('SELECT COUNT(*) AS polygons FROM mupolygon WHERE mupolygonkey IN ',
    "(SELECT mupolygonkey FROM SDA_Get_Mupolygonkey_from_intersection_with_WktWgs84('%s'))"), wkt)
  day03_sda(q, file.path(cache_dir, 'count.json'))
  last <- '0'; page <- 1L
  repeat {
    q <- sprintf(paste0('SELECT TOP 3000 mupolygonkey,mukey,mupolygongeo.STAsText() AS wkt ',
      'FROM mupolygon WHERE mupolygonkey > %s AND mupolygonkey IN ',
      "(SELECT mupolygonkey FROM SDA_Get_Mupolygonkey_from_intersection_with_WktWgs84('%s')) ",
      'ORDER BY mupolygonkey'), last, wkt)
    rows <- day03_sda(q, file.path(cache_dir, sprintf('soil-%03d.json', page)))
    n <- nrow(rows) - 1L
    message('SDA page ', page, ': ', n, ' polygons')
    if (n == 0) break
    last <- tail(rows[, 1], 1)
    if (n < 3000) break
    page <- page + 1L
  }
  invisible(cache_dir)
}
if (sys.nframe() == 0L) acquire_day03()
