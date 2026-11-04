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

Day02 remains `draft: true`, and no default-branch push or publication is authorized by verification. Day03 needs user scope decisions before implementation; Day01 implementation and review are recorded below. Review the native-R map and prose before publication; the original visual approval applied to the prototype.

## Day 01 implementation, 2026-11-04

Sean selected the Andes earthquake concept after reviewing three proposals.
The planning-only status recorded above is superseded for Day01.

- Native R USGS CSV acquisition: 3,478 M ≥4 earthquakes, 2021–2025,
  76–62°W and 28–14°S, 0–700 km depth. Actual range: 2.139–619.384 km.
- Matching section: 1,612 events in the explicitly marked 24–20°S band.
  Shared horizontal projection and equal horizontal/vertical kilometer scales;
  no fitted slab surface. Broad-band projection limitations documented.
- Cached USGS and pinned Natural Earth coastline/land SHA-256 checks: PASS.
- `Rscript tests/test-day01-map.R`: PASS; source snapshot, deep/shallow section
  coverage, projection against great-circle distance, changed-source rejection,
  PNG dimensions/signature, and executed freeze checked.
- Quarto render with `--execute -M draft:false`: PASS; both R chunks executed.
  Unrelated existing listing-preview warnings appeared for other posts.
- Legacy `validate_post.R`: `NO_PLOTS`, because its figure-html path rule excludes
  the artifact PNG displayed by `include_graphics()`. Actual PNG/freeze validation
  is covered by the Day01 test. Reported article length: 679 words.
- PNG inspected locally; label placement corrected after first render.
- Day01 land/ocean shading was added and Sean approved the result for commit and push.
  Day01 remains draft; Day03 still needs scope decisions.
