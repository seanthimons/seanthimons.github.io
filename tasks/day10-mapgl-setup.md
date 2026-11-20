# Day 10 mapgl setup

Work uses `feat/30daymap-day10-prompting-only`, based on master after Day 9.
The mapping topic and model-service prompt remain to be selected.

## Local runtime

Verified locally with mapgl 0.5.2 from CRAN on November 12, 2026.

Use the existing `scripts/map-r.sh` launcher and ignored `.R-library`.
Install from CRAN source on Linux, overriding any user-level binary default:

```sh
sh scripts/map-r.sh -e 'install.packages("mapgl", lib = ".R-library", repos = "https://cloud.r-project.org", type = "source")'
```

Mapbox basemaps use `MAPBOX_PUBLIC_TOKEN`, saved locally in the ignored
project-root `.Renviron`. That file has owner-only permissions. Supply public
`pk.` tokens through the secure credential form; never use a secret `sk.` token.
R reads this file when starting from the project root.

Mapbox includes the public token in the generated HTML and meters map loads.
Review the account's usage limits before publishing. MapLibre is also available
through mapgl and can use basemaps that need no token.

## Smoke check

```sh
sh scripts/map-r.sh scripts/check-mapgl.R
```

This checks package availability, access to Mapbox Standard and generation of a
synthetic 3D tower widget. Output goes to the ignored
`data/30daymap/2026/day10/mapgl-smoke.html` and its dependency folder.
The tower is test geometry, not a data-center observation.

The check makes one authenticated style request. It does not test browser WebGL
rendering. The interactive map needs network access for Mapbox resources;
saved source-data reductions and frozen post execution do not make tiles offline.

Sources: [mapgl installation](https://walker-data.com/mapgl/),
[token setup and MapLibre](https://walker-data.com/mapgl/articles/getting-started.html),
[Kyle Walker's Day 10 example](https://walker-data.com/map-challenge-2026/maps/day10/).
