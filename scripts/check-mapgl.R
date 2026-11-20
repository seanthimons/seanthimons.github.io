#!/usr/bin/env Rscript
# Run from the project root with sh scripts/map-r.sh scripts/check-mapgl.R.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
required <- c("mapgl", "sf", "htmlwidgets", "httr", "magrittr")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))
library(magrittr)
token <- Sys.getenv("MAPBOX_PUBLIC_TOKEN")
if (!startsWith(token, "pk.")) stop("Set MAPBOX_PUBLIC_TOKEN to a public pk. token in the ignored .Renviron file.")
# Check authorization without printing the token or a URL containing it.
response <- httr::GET("https://api.mapbox.com/styles/v1/mapbox/standard",
                      query = list(access_token = token), httr::timeout(30))
status <- httr::status_code(response)
if (status != 200L) stop("Mapbox Standard style returned HTTP ", status)
stopifnot(httr::content(response, as = "parsed")$version == 8L)
stopifnot(all(c("add_fill_extrusion_layer", "add_slider_control") %in% getNamespaceExports("mapgl")))

# A synthetic tower tests extrusion serialization; it represents no real building.
tower <- sf::st_as_sf(data.frame(label = "Synthetic setup test: 500 m tower",
  wkt = "POLYGON((-84.515 39.1,-84.51 39.1,-84.51 39.104,-84.515 39.104,-84.515 39.1))"),
  wkt = "wkt", crs = 4326)
map <- mapgl::mapboxgl(style = mapgl::mapbox_style("standard"),
  center = c(-84.5125, 39.102), zoom = 13, pitch = 55, bearing = -20,
  height = "90vh", hash = TRUE,
  config = list(basemap = list(theme = "monochrome", lightPreset = "night", show3dObjects = FALSE))) %>%
  mapgl::add_fill_extrusion_layer(id = "setup-tower", source = tower,
    fill_extrusion_color = "#EBC06D", fill_extrusion_height = 500,
    fill_extrusion_opacity = 0.85, tooltip = "label") %>%
  mapgl::add_navigation_control()
stopifnot(inherits(map, "mapboxgl"), length(map$x$layers) == 1,
          map$x$layers[[1]]$id == "setup-tower")
out <- "data/30daymap/2026/day10/mapgl-smoke.html"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
htmlwidgets::saveWidget(map, out, selfcontained = FALSE, title = "mapgl setup: synthetic tower")
cat("mapgl ", as.character(utils::packageVersion("mapgl")),
    ": Mapbox Standard HTTP 200; synthetic 3D widget saved to ", out, "\n", sep = "")
cat("The widget contains the public token. It requires network access and a WebGL-capable browser.\n")
