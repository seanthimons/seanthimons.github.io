#!/usr/bin/env Rscript
# Network access is explicit. Raw sources stay in the ignored data cache.
library(magrittr)
source("posts/2026-11-06-30daymap-06-vintage/render-map.R")
if (!"--download" %in% commandArgs(trailingOnly = TRUE)) stop("Opt in with --download")
options(timeout = 180)
dir.create(day06_cache, recursive = TRUE, showWarnings = FALSE)
urls <- c(
  west.tif = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Maps/HistoricalTopo/GeoTIFF/OH/OH_West%20Cincinnati_709982_1914_62500_geo.tif",
  east.tif = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Maps/HistoricalTopo/GeoTIFF/OH/OH_East%20Cincinnati_708568_1914_62500_geo.tif",
  `queen-city.html` = "https://queencitychapter.com/brewinghistory/preprohibition.htm",
  `brewing-1903.txt` = "https://archive.org/download/onehundredyearso0000vari_c0n2/onehundredyearso0000vari_c0n2_djvu.txt",
  `bavarian-exhibit.html` = "https://www.pinemeer.org/copy-of-special-museums"
)
bboxes <- c(central = "-84.535,39.108,-84.508,39.125", west = "-84.548,39.12,-84.528,39.137",
            north = "-84.548,39.155,-84.53,39.175", covington = "-84.523,39.077,-84.505,39.09",
            newport = "-84.502,39.085,-84.485,39.1", mohawk = "-84.532,39.122,-84.515,39.136",
            harrison = "-84.56,39.124,-84.545,39.136", bavarian = "-84.523,39.067,-84.513,39.078",
            westend = "-84.54,39.099,-84.523,39.114")
urls <- c(urls, stats::setNames(paste0("https://api.openstreetmap.org/api/0.6/map?bbox=", bboxes),
                               paste0("osm-", names(bboxes), ".osm")))
fetch <- function(url, path) {
  if (!file.exists(path)) {
    tmp <- paste0(path, ".part")
    utils::download.file(url, tmp, mode = "wb", method = "libcurl", quiet = TRUE)
    if (file.size(tmp) < 100) stop("Truncated download: ", url)
    if (!file.rename(tmp, path)) stop("Could not save ", path)
  }
}
for (i in seq_along(urls)) fetch(urls[i], file.path(day06_cache, names(urls)[i]))
history <- rvest::read_html(file.path(day06_cache, "queen-city.html")) %>% rvest::html_text2()
writeLines(history, file.path(day06_cache, "queen-city.txt"))
# Keep a small index into the primary history without republishing its text.
paragraphs <- strsplit(history, "\n\n", fixed = TRUE)[[1]]
patterns <- c("HERANCOURT", "KAUFFMAN", "WINDISCH-MUHLHAUSER", "Moerlein", "HAUCK", "SCHALLER",
              "FOSS", "LACKMAN", "BELLEVUE", "BRUCKMANN", "WETTERER", "OHIO UNION", "MOHAWK",
              "BAVARIAN", "JUNG", "WIEDEMANN", "HUDEPOHL", "JACKSON", "FAIRMONT", "CROWN", "GAMBRINUS", "ADAM")
index <- do.call(rbind, lapply(patterns, function(p) {
  hits <- grep(p, paragraphs, ignore.case = TRUE)
  if (!length(hits)) stop("History no longer contains ", p)
  data.frame(firm_pattern = p, paragraph = hits)
}))
utils::write.csv(index, file.path(day06_root, "history-index.csv"), row.names = FALSE)

decisions <- utils::read.csv(file.path(day06_root, "location-decisions.csv"), colClasses = "character", na.strings = "")
nodes <- new.env(parent = emptyenv())
ways <- new.env(parent = emptyenv())
way_ids <- decisions$osm_id[decisions$osm_type == "way"]
node_ids <- na.omit(c(decisions$osm_id[decisions$osm_type == "node"], decisions$second_osm_id))
documents <- lapply(paste0("osm-", names(bboxes), ".osm"), function(f) {
  doc <- xml2::read_xml(file.path(day06_cache, f))
  if (xml2::xml_name(doc) != "osm") stop("Not an OSM API response: ", f)
  doc
})
select_ids <- function(doc, type, ids) {
  xpath <- paste0("/osm/", type, "[", paste0("@id='", unique(ids), "'", collapse = " or "), "]")
  xml2::xml_find_all(doc, xpath)
}
for (doc in documents) {
  for (e in select_ids(doc, "way", way_ids)) {
    refs <- xml2::xml_attr(xml2::xml_find_all(e, "nd"), "ref")
    assign(xml2::xml_attr(e, "id"), list(refs = refs), ways)
    node_ids <- union(node_ids, refs)
  }
}
for (doc in documents) {
  for (e in select_ids(doc, "node", node_ids)) {
    assign(xml2::xml_attr(e, "id"), list(xy = as.numeric(xml2::xml_attrs(e)[c("lon", "lat")])), nodes)
  }
}
ocr <- paste(readLines(file.path(day06_cache, "brewing-1903.txt"), warn = FALSE), collapse = "\n")
ocr <- gsub("-[[:blank:]]*\n[[:blank:]]*", "", ocr)
ocr <- gsub("[[:space:]|]+", " ", ocr)
decisions <- utils::read.csv(file.path(day06_root, "location-decisions.csv"), colClasses = "character", na.strings = "")
rows <- lapply(seq_len(nrow(decisions)), function(i) {
  d <- decisions[i, ]
  named <- !is.na(d$ocr_pattern) && grepl(d$ocr_pattern, ocr, ignore.case = TRUE, perl = TRUE)
  if (named != (d$in_1903_source == "TRUE")) stop("1903 evidence changed for ", d$name)
  ids <- na.omit(c(d$osm_id, d$second_osm_id))
  if (d$osm_type == "node") coords <- do.call(rbind, lapply(ids, function(id) get(id, nodes)$xy)) else {
    refs <- get(d$osm_id, ways)$refs
    if (refs[1] == tail(refs, 1)) refs <- head(refs, -1)
    coords <- do.call(rbind, lapply(refs, function(id) get(id, nodes)$xy))
  }
  xy <- colMeans(coords)
  data.frame(name = d$name, city = d$city, address_text = d$address_text, lon = round(xy[1], 7),
             lat = round(xy[2], 7), placed_by = d$placed_by, in_1903_source = named,
             source_url = urls[["queen-city.html"]],
             osm_url = paste0("https://www.openstreetmap.org/", d$osm_type, "/", d$osm_id),
             second_osm_url = if (length(ids) > 1) paste0("https://www.openstreetmap.org/node/", ids[2]) else "",
             source_1903_url = urls[["brewing-1903.txt"]],
             extra_source_url = if (is.na(d$extra_source_url)) "" else d$extra_source_url,
             retrieved_date = format(Sys.Date()), placement_note = d$placement_note, history_note = d$history_note)
})
utils::write.csv(do.call(rbind, rows), file.path(day06_root, "breweries.csv"), row.names = FALSE, na = "")
read_day06_breweries()
prepare_day06_basemap()
source_paths <- file.path(day06_cache, names(urls))
input_paths <- c(file.path(day06_cache, "mosaic.tif"), file.path(day06_root, c("breweries.csv", "location-decisions.csv", "excluded-firms.csv")))
fingerprint <- function(paths) data.frame(path = paths,
    sha256 = vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), ""))
snapshot <- list(retrieved_date = format(Sys.Date()), sources = cbind(url = unname(urls), fingerprint(source_paths)),
                 render_inputs = fingerprint(input_paths), crs = list(
                   west = terra::crs(terra::rast(source_paths[1])), east = terra::crs(terra::rast(source_paths[2])),
                   display = day06_config()$crs),
                 note = "1914-labelled editions; scan edition dates are not a census of brewery operation. OSM coordinates are site or block proxies; 1903 flags identify firms, not addresses.")
jsonlite::write_json(snapshot, file.path(day06_root, "source-snapshot.json"), pretty = TRUE, auto_unbox = TRUE)
