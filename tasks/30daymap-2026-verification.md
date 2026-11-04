# Integration verification

## Initial migration

Base: `origin/master` commit `c9a5b57bf3023c2dcffc6469911ba6b82f9b7551`. Scoped migration checkpoint: `f5c3c08`. Original checkout dirt was preserved in a separate worktree.

Day01 and Day03 remain unanswered scoping records, not invented map implementations. All 26 pending Day05–30 cron prompts were updated and read back without changing schedule, target, skills, continuation, repeat or enabled status. Completed jobs were not re-fired.

## Native R execution, 2026-11-04

Sean authorized installation after the initial missing-dependency blocker. `pak` installed `terra` 1.9-50 and `sf` 1.1-3 plus dependencies in ignored `.R-library/`. Missing Debian 13 GIS runtimes were downloaded and extracted into ignored `.sysdeps/`; no sudo, system install, or maintainer scripts. Loaded GEOS 3.13.1, GDAL 3.10.3, PROJ 9.6.0. Runtime and R package version records are committed separately.

- `sh scripts/map-r.sh tests/test-day02-map.R`: PASS, including the now-active terra Gaussian constant-surface integration check.
- Native R cache validation on actual USGS tiles: PASS. MD5 n40w085 `d92865379ad4ff7c49ac9a63e8023f9c`; n39w085 `5a86454543ad939a12a8557324c819fa`.
- `sh scripts/map-r.sh posts/2026-11-02-30daymap-02-lines/render-map.R`: PASS against the actual cached USGS raw tiles, not Python intermediates.
- `sh scripts/map-r.sh tests/test-day02-real-output.R`: PASS. Source fingerprints, complete finite 40 km terrain coverage, EPSG:26916 at 20 m, 24 km crop, valid WGS84 contour exports, 2,000-pixel PNG and expected background checked.
- Elevation range: approximately 138.727–294.149 m. Fifteen elevation-level contour features in the displayed crop. Each feature may contain multiple disjoint lines, so this is not the Python prototype's segment-count metric.
- Native R PNG visually inspected. Approved B framing and Night survey palette retained; no obvious grid seam or missing-coverage block. Survey accuracy and exact shoreline positions are not claimed.
- Day02 Quarto render with `--execute`: PASS, executing both terrain build and map display. Stale blocked/prototype-only notices removed from the active article. Historical previews remain under `reference/`.
- Day01 and Day03 planning QMDs render to HTML, but this does not mean their maps exist.
- Cache/library/runtime and nested TIFF ignore checks PASS. Large derived GeoJSON and SVG remain regenerable/ignored. No packages, runtime libraries, DEBs, or raw DEMs belong in Git.

## Remaining editorial gates

Day02 remains `draft: true`, and no default-branch push or publication is authorized by verification. Day01 and Day03 need user scope decisions before implementation. Review the native-R map and prose before publication; the original visual approval applied to the prototype.
