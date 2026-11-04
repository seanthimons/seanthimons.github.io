# Day 02: local R runtime and reproduction

Run from this branch's worktree root. Nothing requires sudo. The map pipeline is native R; the shell wrapper only sets runtime paths and starts R or Quarto.

## Setup

```sh
Rscript scripts/setup-map-r.R
```

The explicit setup recipe uses `pak` to install spatial R packages into ignored `.R-library/`. This host is Debian 13 and lacked GDAL/PROJ/GEOS runtimes. The recipe simulates APT resolution, downloads the missing Debian runtime packages, and extracts them with `dpkg-deb -x` into ignored `.sysdeps/`. It does not install system packages, execute maintainer scripts, change global libraries, or use sudo. It assumes Debian 13's runtime package names and binary-compatible R packages; it is not a cross-distribution installer. `pak` and Quarto's R dependencies must already be available in the ordinary R library.

The verified R dependency versions and their transitive dependencies are recorded in `tasks/30daymap-r.lock`. This campaign lockfile is separate from site-wide configuration; setup does not activate renv or alter the whole blog. The simple pak setup resolves currently available binaries. To restore the recorded R package set instead, with `renv` already available, use:

```r
renv::restore(lockfile = "tasks/30daymap-r.lock", library = ".R-library", prompt = FALSE)
```

The extracted runtime package versions are recorded in `tasks/30daymap-runtime-packages.txt`. The local APT plan/debs remain in `.sysdeps/` for audit; a future APT mirror may supersede those package versions.

## Test and render

```sh
sh scripts/map-r.sh tests/test-day02-map.R
sh scripts/map-r.sh posts/2026-11-02-30daymap-02-lines/render-map.R
sh scripts/map-r.sh tests/test-day02-real-output.R
sh scripts/map-r.sh --quarto render posts/2026-11-02-30daymap-02-lines/2026-11-02-30daymap-02-lines.qmd --execute -M draft:false
```

`-M draft:false` is a local-review override only. The source remains `draft: true`; do not apply this override in publication automation. Without it, Quarto executes the draft but suppresses the article body in the rendered HTML.

If the raw input cache is absent, add `--download` to the terrain command. This invokes R's `download.file()` against USGS. Quarto execution intentionally requires cached inputs; no network requests or installations occur while rendering the post.

The wrapper scopes `LD_LIBRARY_PATH`, `PROJ_DATA`, and `GDAL_DATA` to its subprocess. The R script prepends `.R-library/` while retaining the ordinary R library. Use `sh scripts/map-r.sh` rather than a bare Rscript invocation on this host.

## Outputs and evidence

- Raw source tiles: ignored `data/30daymap/2026/day02/`.
- Unsmoothed and smoothed terrain TIFFs: ignored Day02 `artifacts/`.
- Large derived contour GeoJSON and SVG: generated but ignored, reproducible from raw tiles.
- Native-R PNG, PDF and compact `provenance.R`: tracked Day02 `artifacts/`.
- Original approved palette/framing studies: `reference/`, labeled historical prototype evidence.
- Native render: projected elevation range approximately 138.727–294.149 m, complete 40 km terrain coverage, 10 m contours grouped into 15 elevation-level features over the final 24 km crop. This is not directly comparable to the Python prototype's segment count.

Day02 remains `draft: true`. Successful execution is not authorization to publish.
