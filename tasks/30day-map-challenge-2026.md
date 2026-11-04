# 30DayMapChallenge 2026 — publication campaign

## Objective

Publish **one compact Quarto post per daily map** during November 2026. Each post is a reproducible cartographic study, not an essay pretending to be a map. The map is the main artifact; the post records the data provenance, cartographic decision, package experiment, and source code.

## Reality check

Thirty full essays in thirty days is a production failure. Thirty **small, well-made map notes** is feasible if the post contract stays fixed and the data/package decisions are prepared ahead of time.

The official 30-theme list is published at https://30daymapchallenge.com/2026/ (verified 2026-10-02). The canonical local transcription is `tasks/30day-map-challenge-2026-themes.csv`. Do not pre-scope all 30 maps: use the limited daily interview to assign the data, package lane, fallback, and visual thesis before building each post.

## Fixed post contract

Every post should contain:

1. a title with day number and official theme;
2. the finished map near the top;
3. one paragraph: the geographic question / visual thesis;
4. `Data & provenance`: source, retrieval date, license/terms, geographic CRS;
5. `Method`: package(s), projection, scale/classification, and one design choice;
6. a visible code chunk or linked source script; and
7. an `Alt text` line describing the map's actual visual content.

Target: **400–700 words plus code**, not a miniature literature review.

## Package rotation (initial slate)

| Lane | Candidate package(s) | Use it for |
|---|---|---|
| Vector foundation | `sf` | vector data, CRS work, geometry operations, and the common object model |
| Thematic cartography | `tmap` (static mode), `mapsf` | map-native layered grammar; a genuinely non-ggplot base-graphics route |
| WebGL / HTML | `mapgl` | MapLibre/Mapbox GL, globes, 3D, heatmaps, and a small number of HTML-first posts |
| Network / movement | `sfnetworks`, `tidygraph` | streams, roads, transport, routing, and connectivity |
| Raster / terrain | `terra`, `stars`, `rayshader` | raster analysis, multidimensional data cubes, hillshade, and 3D relief |
| Specialist distortion | `cartogram` | explicit area distortion with a conventional reference map alongside it |
| Reproducible source data | `osmdata`, `rnaturalearth` | scripted OSM/Natural Earth acquisition, caching, and attribution |
| Grammar / annotation | `ggplot2`, `ggspatial`, `ggrepel`, `ggfx` | composition glue, labels, scale bars, north arrows, and finishing effects |

`ggplot2` is allowed as composition glue. It must not be the only new thing learned every day. `tmap` must use static plot mode for this goal; its interactive mode is Leaflet-family tooling.

### Reproducibility constraints

- Use `sf` as the shared vector format; use `terra` for ordinary raster work and reserve `stars` for cases where a time/data-cube dimension is substantively the point.
- Cache OSM/Natural Earth inputs and record their source/attribution. Do not rely on live web queries during final Quarto renders.
- HTML-widget posts need a static image fallback for social sharing.
- Pin the eventual package set with `renv`; Linux source installs for `sf`/`terra`/`stars` require GDAL, GEOS, PROJ, sqlite3, and (for `terra`) its additional build prerequisites. Smoke-test `rayshader` in the actual headless Quarto environment before assigning it a day.

## Cadence

- **Now → theme announcement:** build a source/data pantry; install and smoke-test two packages per week; make one reusable Quarto post skeleton and a deterministic scaffolder.
- **After themes:** assign a package lane + dataset + fallback to each theme within 48 hours. Use `scripts/scaffold_30day_map_challenge.R` to create the 30 dated post directories.
- **October:** produce five complete reserve maps. These are not cheats; they are the buffer that keeps work from becoming midnight sludge.
- **November:** publish the finished map daily; commit the QMD, source data recipe, and rendered freeze together. No direct-to-`master` automation.

## Definition of done for a day

- [ ] Official theme is represented faithfully.
- [ ] Map has a reproducible data acquisition/prep path.
- [ ] At least one deliberate cartographic decision is documented.
- [ ] The post renders locally with execution.
- [ ] Image alt text and source/license attribution are present.
- [ ] Changes are reviewed on a branch before publication.

## Theme intake

When the official 30-item list is published, create `tasks/30day-map-challenge-2026-themes.csv` from `tasks/30day-map-challenge-2026-themes.example.csv`, fill `theme` with the official wording, then run:

```bash
Rscript scripts/scaffold_30day_map_challenge.R \
  --themes tasks/30day-map-challenge-2026-themes.csv \
  --posts-root posts
```

The scaffolder intentionally refuses anything other than a complete, unique 30-day CSV. It should be run on a feature branch.

## Sources

- Official challenge: https://30daymapchallenge.com/#2026-themes
- Mapping resources: https://30daymapchallenge.com/resources/
