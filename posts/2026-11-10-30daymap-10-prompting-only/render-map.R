#!/usr/bin/env Rscript
# Day 10 (Prompting only): Lake Superior with the water taken out. NOAA NCEI bathymetry becomes 3D terrain with the
# named wrecks from Wikidata on the floor; translucent hex columns stand in for the water and fade as you zoom in.
# acquire_day10() is the only network step. build_day10() writes the committed tiles and tables; render_day10() only
# reads them. Run from the repository root; sourcing only defines functions.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
day10_root <- "posts/2026-11-10-30daymap-10-prompting-only"

day10_config <- function() {
  list(
    cache = "data/30daymap/2026/day10/raw",
    ncei_url = "https://www.ngdc.noaa.gov/mgg/greatlakes/superior/data/geotiff/superior_lld.geotiff.tar.gz",
    ncei_tif = "superior_lld/superior_lld.tif",
    # NCEI depths are relative to Lake Superior's Low Water Datum, 183.2 m above IGLD 1985.
    datum_m = 183.2,
    # Wikidata search box (lon/lat corners) and the classes that count as a wreck.
    box = c(west = -92.3, south = 46.3, east = -84.3, north = 49.1),
    enc_url = "https://encdirect.noaa.gov/arcgis/rest/services/encdirect/enc_general/MapServer/29/query",
    # Wikidata hits that are not wrecks on Lake Superior's floor. A depth rule cannot do this: nearshore wrecks fall
    # on land in a 90 m grid, and museum ships in harbors fall in water.
    exclude = c(
      Q6718134 = "museum ship on display at Sault Ste. Marie",
      Q7866256 = "museum ship (USCGC Sundew) on display at Duluth",
      Q20642364 = "replica Viking ship on display at Duluth",
      Q48815473 = "survived the 1913 storm; not wrecked",
      Q7272132 = "sank in Torch Lake, not Lake Superior",
      Q85749479 = "inland lake in Minnesota, not Lake Superior"
    ),
    # Grid cells shallower than this are not given a depth: the grid cannot resolve the shoreline.
    floor_min_m = 2,
    zooms = 4:9, tile_px = 256,
    hex_m = 6000, crs = "EPSG:3175",
    exaggeration = 30,
    fitzgerald = "Q1286267",
    # Extent of the NCEI grid, so MapLibre only asks for tiles that exist.
    grid_bounds = c(-92.2, 46.0, -84.0, 49.5)
  )
}

# ---- acquisition --------------------------------------------------------------------------------------------------
day10_sparql <- function(box) {
  sprintf('SELECT ?item ?itemLabel ?coord (SAMPLE(?t) AS ?type) (SAMPLE(?wp) AS ?wiki) WHERE {
  SERVICE wikibase:box { ?item wdt:P625 ?coord .
    bd:serviceParam wikibase:cornerWest "Point(%s %s)"^^geo:wktLiteral .
    bd:serviceParam wikibase:cornerEast "Point(%s %s)"^^geo:wktLiteral . }
  { ?item wdt:P31/wdt:P279* wd:Q852190 } UNION { ?item wdt:P793 wd:Q852190 } UNION
  { ?item wdt:P31 wd:Q11446 } UNION { ?item wdt:P31/wdt:P279* wd:Q2235308 }
  OPTIONAL { ?item wdt:P31 ?ti . ?ti rdfs:label ?t . FILTER(LANG(?t) = "en") }
  OPTIONAL { ?wp schema:about ?item ; schema:isPartOf <https://en.wikipedia.org/> }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
} GROUP BY ?item ?itemLabel ?coord', box[["west"]], box[["south"]], box[["east"]], box[["north"]])
}

acquire_day10 <- function(cfg = day10_config()) {
  dir.create(cfg$cache, recursive = TRUE, showWarnings = FALSE)
  tgz <- file.path(cfg$cache, basename(cfg$ncei_url))
  if (!file.exists(tgz)) curl::curl_download(cfg$ncei_url, tgz)
  utils::untar(tgz, exdir = cfg$cache)

  h <- curl::new_handle(useragent = "30daymap-r-script/0.1", httpheader = "Accept: text/csv")
  url <- paste0("https://query.wikidata.org/sparql?query=", curl::curl_escape(day10_sparql(cfg$box)))
  curl::curl_download(url, file.path(cfg$cache, "wikidata-wrecks.csv"), handle = h)

  q <- list(where = "1=1", geometryType = "esriGeometryEnvelope", inSR = 4326, outSR = 4326, f = "json",
            spatialRel = "esriSpatialRelIntersects", outFields = "OBJNAM,CATWRK,VALSOU",
            geometry = paste(cfg$box[c("west", "south", "east", "north")], collapse = ","))
  url <- paste0(cfg$enc_url, "?", paste(names(q), vapply(q, \(v) curl::curl_escape(v), ""), sep = "=", collapse = "&"))
  curl::curl_download(url, file.path(cfg$cache, "enc-wrecks.json"))
  # Both services answer errors with HTTP 200, so check the bodies before anything is built from them.
  if (nrow(utils::read.csv(file.path(cfg$cache, "wikidata-wrecks.csv"))) == 0) stop("Wikidata returned no wrecks")
  if (!length(jsonlite::read_json(file.path(cfg$cache, "enc-wrecks.json"))$features)) {
    stop("ENC Direct returned no wreck features: ", readLines(file.path(cfg$cache, "enc-wrecks.json"), warn = FALSE)[1])
  }
  invisible(cfg$cache)
}

day10_grid <- function(cfg) terra::rast(file.path(cfg$cache, cfg$ncei_tif))

# ---- terrain tiles ------------------------------------------------------------------------------------------------
# Terrarium encoding: elevation = R * 256 + G + B / 256 - 32768.
day10_terrarium <- function(elev) {
  v <- elev + 32768
  r <- floor(v / 256); g <- floor(v) %% 256; b <- pmin(floor((v - floor(v)) * 256), 255)
  array(c(r, g, b) / 255, dim = c(dim(elev), 3))
}
day10_unterrarium <- function(rgb) rgb[, , 1] * 255 * 256 + rgb[, , 2] * 255 + rgb[, , 3] * 255 / 256 - 32768

# Slippy-map tile index and the Web Mercator bounds of a tile.
day10_tile_xy <- function(lon, lat, z) {
  n <- 2^z
  c(x = floor((lon + 180) / 360 * n), y = floor((1 - asinh(tan(lat * pi / 180)) / pi) / 2 * n))
}
day10_tile_bounds <- function(x, y, z) {
  half <- 20037508.342789244; size <- 2 * half / 2^z
  c(xmin = -half + x * size, xmax = -half + (x + 1) * size, ymin = half - (y + 1) * size, ymax = half - y * size)
}

build_tiles_day10 <- function(cfg = day10_config(), grid = day10_grid(cfg)) {
  out <- file.path(day10_root, "terrain")
  unlink(out, recursive = TRUE)
  e <- as.vector(terra::ext(grid))
  n <- 0L
  for (z in cfg$zooms) {
    lo <- day10_tile_xy(e[["xmin"]], e[["ymax"]], z); hi <- day10_tile_xy(e[["xmax"]], e[["ymin"]], z)
    # Coarser source for low zooms keeps each reprojection small; never finer than the tile pixel.
    src <- if (z <= 7) terra::aggregate(grid, fact = 2^(8 - z), fun = "mean", na.rm = TRUE) else grid
    for (x in lo[["x"]]:hi[["x"]]) for (y in lo[["y"]]:hi[["y"]]) {
      b <- day10_tile_bounds(x, y, z)
      tmpl <- terra::rast(terra::ext(b[c("xmin", "xmax", "ymin", "ymax")]), nrows = cfg$tile_px, ncols = cfg$tile_px,
                          crs = "EPSG:3857")
      elev <- terra::as.matrix(terra::project(src, tmpl, method = "bilinear"), wide = TRUE)
      # Outside the NCEI grid: hold at the lake datum instead of letting NA decode as -32768 m.
      elev[is.na(elev)] <- 0
      dir.create(file.path(out, z, x), recursive = TRUE, showWarnings = FALSE)
      png::writePNG(day10_terrarium(elev + cfg$datum_m), file.path(out, z, x, paste0(y, ".png")))
      n <- n + 1L
    }
  }
  message("Wrote ", n, " terrain tiles")
  invisible(n)
}

# ---- wrecks and water columns -------------------------------------------------------------------------------------
build_wrecks_day10 <- function(cfg = day10_config(), grid = day10_grid(cfg)) {
  wd <- utils::read.csv(file.path(cfg$cache, "wikidata-wrecks.csv"))
  xy <- regmatches(wd$coord, regexec("Point\\(([-0-9.]+) ([-0-9.]+)\\)", wd$coord))
  ok <- lengths(xy) == 3
  wd <- wd[ok, ]
  wd$lon <- as.numeric(vapply(xy[ok], `[`, "", 2)); wd$lat <- as.numeric(vapply(xy[ok], `[`, "", 3))
  wd$qid <- sub(".*/", "", wd$item)
  wd <- wd[!duplicated(wd$qid), ]
  pts <- terra::vect(wd[c("lon", "lat")], geom = c("lon", "lat"), crs = "EPSG:4326")
  wd$floor_m <- round(terra::extract(grid, terra::project(pts, grid))[[2]], 1)
  wd$excluded <- unname(cfg$exclude[wd$qid])
  wd$shared_coord <- duplicated(wd[c("lon", "lat")]) | duplicated(wd[c("lon", "lat")], fromLast = TRUE)
  out <- data.frame(qid = wd$qid, name = wd$itemLabel, type = wd$type, lon = wd$lon, lat = wd$lat,
                    floor_m = wd$floor_m, excluded = wd$excluded, shared_coord = wd$shared_coord, wiki = wd$wiki)
  out <- out[order(out$name), ]
  utils::write.csv(out, file.path(day10_root, "wrecks.csv"), row.names = FALSE)

  enc <- jsonlite::read_json(file.path(cfg$cache, "enc-wrecks.json"))$features
  enc <- unique(data.frame(lon = round(vapply(enc, \(f) f$geometry$x, 0), 5),
                           lat = round(vapply(enc, \(f) f$geometry$y, 0), 5),
                           category = vapply(enc, \(f) f$attributes$CATWRK %||% NA_character_, "")))
  utils::write.csv(enc, file.path(day10_root, "enc-wrecks.csv"), row.names = FALSE)
  invisible(out)
}

build_columns_day10 <- function(cfg = day10_config(), grid = day10_grid(cfg)) {
  lake <- terra::aggregate(grid, fact = 10, fun = "mean", na.rm = TRUE) < 0
  lake <- sf::st_as_sf(terra::as.polygons(lake))
  lake <- sf::st_transform(sf::st_make_valid(lake[as.logical(lake[[1]]), ]), cfg$crs)
  hex <- sf::st_make_grid(lake, cellsize = cfg$hex_m, square = FALSE)
  cen <- sf::st_centroid(hex)
  depth <- terra::extract(grid, terra::vect(sf::st_transform(cen, terra::crs(grid))))[[2]]
  keep <- !is.na(depth) & depth < -cfg$floor_min_m
  cols <- sf::st_sf(depth_m = round(-depth[keep]), geometry = hex[keep])
  cols <- suppressWarnings(sf::st_intersection(cols, sf::st_union(lake)))
  cols <- sf::st_transform(sf::st_collection_extract(cols, "POLYGON"), 4326)
  f <- file.path(day10_root, "water-columns.geojson")
  unlink(f)
  sf::st_write(cols, f, quiet = TRUE, layer_options = "COORDINATE_PRECISION=4")
  invisible(cols)
}

snapshot_day10 <- function(cfg = day10_config()) {
  files <- c(file.path(cfg$cache, c(basename(cfg$ncei_url), "wikidata-wrecks.csv", "enc-wrecks.json")),
             file.path(day10_root, c("wrecks.csv", "enc-wrecks.csv", "water-columns.geojson")))
  jsonlite::write_json(list(
    retrieved = format(Sys.Date()),
    sources = list(ncei = cfg$ncei_url, wikidata = "https://query.wikidata.org/sparql", enc = cfg$enc_url),
    sha256 = as.list(stats::setNames(vapply(files, \(f) digest::digest(file = f, algo = "sha256"), ""), basename(files)))
  ), file.path(day10_root, "source-snapshot.json"), auto_unbox = TRUE, pretty = TRUE)
}

check_day10_snapshot <- function() {
  s <- jsonlite::read_json(file.path(day10_root, "source-snapshot.json"))
  for (f in c("wrecks.csv", "enc-wrecks.csv", "water-columns.geojson")) {
    if (digest::digest(file = file.path(day10_root, f), algo = "sha256") != s$sha256[[f]]) {
      stop(f, " does not match source-snapshot.json; rerun build_day10().")
    }
  }
  invisible(TRUE)
}

build_day10 <- function(cfg = day10_config()) {
  grid <- day10_grid(cfg)
  build_tiles_day10(cfg, grid)
  build_wrecks_day10(cfg, grid)
  build_columns_day10(cfg, grid)
  snapshot_day10(cfg)
}

# ---- widget -------------------------------------------------------------------------------------------------------
# mapgl passes only a TileJSON url for raster-dem sources, so the terrain source, terrain and hillshade are added in
# JavaScript. Tile URLs are made absolute from the page address because MapLibre fetches them from a worker.
day10_js <- function(cfg, bounds, fitz) {
  d <- cfg$datum_m
  sprintf("function(el, x) {
  const map = this.getMap();
  const add = () => {
    const base = location.href.split(/[?#]/)[0].replace(/[^/]*$/, '') + 'terrain/{z}/{x}/{y}.png';
    const dem = {type: 'raster-dem', tiles: [base], encoding: 'terrarium', tileSize: %d, minzoom: %d, maxzoom: %d,
                 bounds: [%s]};
    map.addSource('floor', dem);
    map.addSource('floor-shade', dem);
    map.setTerrain({source: 'floor', exaggeration: %d});
    map.setSky({'sky-color': '#0b1317', 'horizon-color': '#1c2b35', 'fog-color': '#0b1317',
                'sky-horizon-blend': 0.6, 'horizon-fog-blend': 0.6, 'fog-ground-blend': 0.85});
    const below = map.getLayer('water-columns') ? 'water-columns' : undefined;
    // Tiles hold absolute elevation, so the lake floor is everything below the %.1f m datum; land stays clear.
    map.addLayer({id: 'floor-depth', type: 'color-relief', source: 'floor-shade',
      paint: {'color-relief-color': ['interpolate', ['linear'], ['elevation'],
        %.2f, '#16306b', %.2f, '#1d5f9e', %.2f, '#3b9ccc', %.2f, '#9fd8ec', %.2f, 'rgba(0,0,0,0)']}}, below);
    map.addLayer({id: 'floor-hillshade', type: 'hillshade', source: 'floor-shade',
      paint: {'hillshade-exaggeration': 0.85, 'hillshade-shadow-color': '#040b10',
              'hillshade-highlight-color': '#d6ecf5', 'hillshade-accent-color': '#0d2633'}}, below);
  };
  if (map.isStyleLoaded()) add(); else map.once('load', add);
  // The panel control is added after this hook runs, so listen on the widget instead of the button.
  el.addEventListener('click', e => {
    if (e.target.closest('#day10-fitz')) map.flyTo({center: [%f, %f], zoom: 10.6, pitch: 72, bearing: 150,
                                                     duration: 7000, essential: true});
  });
}", cfg$tile_px, min(cfg$zooms), max(cfg$zooms), paste(bounds, collapse = ","), cfg$exaggeration,
          d, d - 400, d - 250, d - 100, d - 0.1, d - 0.01, fitz$lon, fitz$lat)
}

render_day10 <- function(cfg = day10_config()) {
  check_day10_snapshot()
  wrecks <- utils::read.csv(file.path(day10_root, "wrecks.csv"))
  wrecks <- wrecks[is.na(wrecks$excluded), ]
  deep <- wrecks$floor_m < -cfg$floor_min_m
  wrecks$depth <- ifelse(deep, sprintf("%d m (%d ft)", round(-wrecks$floor_m), round(-wrecks$floor_m * 3.28084)),
                         "nearshore, finer than the grid")
  wrecks$tip <- sprintf("<b>%s</b><br>Floor under the charted point: %s", wrecks$name, wrecks$depth)
  fitz <- wrecks[wrecks$qid == cfg$fitzgerald, ]
  wsf <- sf::st_as_sf(wrecks, coords = c("lon", "lat"), crs = 4326)
  cols <- sf::st_read(file.path(day10_root, "water-columns.geojson"), quiet = TRUE)
  cols$tip <- sprintf("Water column: %d m deep", cols$depth_m)
  # MapLibre seats an extrusion's base on the (exaggerated) terrain but does not exaggerate its height.
  cols$top <- cols$depth_m * cfg$exaggeration

  ink <- "#e8eef1"
  tip <- mapgl::tooltip_style(background_color = "#0b1317", background_opacity = 0.94, text_color = ink,
                              border_color = "#ffffff24", border_width = 1, border_radius = 8, font_size = 12,
                              padding = 8, max_width = 260)
  panel <- htmltools::HTML(sprintf(
    '<div style="width:270px;background:#0b1317ee;color:%s;border:1px solid #ffffff24;border-radius:10px;
       padding:11px 13px;font:12.5px/1.45 system-ui,sans-serif">
      <div style="font-size:10.5px;letter-spacing:.09em;text-transform:uppercase;color:#8fb3c4;font-weight:600">
        #30DayMapChallenge · Day 10 · Prompting only</div>
      <div style="font-size:20px;font-weight:700;line-height:1.15;margin:3px 0 7px">Lake Superior, drained</div>
      <div style="color:#c9d3db">The lake floor, %d× vertical exaggeration. Blue columns are the water that was there,
      one per 6 km hexagon, as tall as the lake was deep. Zoom in and they fade, leaving %d named wrecks on the bottom.</div>
      <button id="day10-fitz" style="width:auto;height:auto;margin-top:9px;background:#e9a23b;color:#111;border:0;border-radius:6px;
        padding:6px 10px;font-weight:700;cursor:pointer">Fly to the Edmund Fitzgerald</button>
      <div style="color:#8a99a3;font-size:10.5px;margin-top:8px">Data: NOAA NCEI Lake Superior bathymetry;
      wrecks from Wikidata (CC0). Basemap © CARTO, © OpenStreetMap contributors.</div></div>',
    ink, cfg$exaggeration, nrow(wrecks)))

  map <- mapgl::maplibre(style = mapgl::carto_style("dark-matter-no-labels"), center = c(-87.4, 47.75), zoom = 6.35,
                         pitch = 58, bearing = 8, maxPitch = 80,
                         projection = "mercator") |>
    mapgl::add_fill_extrusion_layer(
      id = "water-columns", source = cols,
      fill_extrusion_color = "#1f5f8a",
      fill_extrusion_height = mapgl::get_column("top"), fill_extrusion_base = 0,
      fill_extrusion_opacity = mapgl::interpolate(property = "zoom", values = c(6.8, 8.4), stops = c(0.4, 0)),
      tooltip = "tip", tooltip_style = tip, max_zoom = 8.5) |>
    mapgl::add_circle_layer(
      id = "wrecks", source = wsf, circle_color = "#e9a23b", circle_radius = 5, circle_stroke_color = "#111",
      circle_stroke_width = 1, tooltip = "tip", tooltip_style = tip) |>
    mapgl::add_symbol_layer(
      id = "fitz-label", source = wsf[wsf$qid == cfg$fitzgerald, ], text_field = "Edmund Fitzgerald",
      text_color = "#f5c46b", text_halo_color = "#000", text_halo_width = 1.5, text_size = 13,
      text_offset = c(0, -1.4), text_anchor = "bottom") |>
    mapgl::add_navigation_control() |>
    mapgl::add_control(panel, position = "top-left")
  htmlwidgets::onRender(map, day10_js(cfg, cfg$grid_bounds, fitz))
}
