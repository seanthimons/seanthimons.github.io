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
sh scripts/map-r.sh --quarto render posts/2026-11-02-30daymap-02-lines/2026-11-02-30daymap-02-lines.qmd --execute
```

Days 01–04 are now marked `draft: false` following Sean's publication approval. Earlier draft-review commands used `-M draft:false`; that override is no longer necessary.

If the raw input cache is absent, add `--download` to the terrain command. This invokes R's `download.file()` against USGS. Quarto execution intentionally requires cached inputs; no network requests or installations occur while rendering the post.

The wrapper scopes `LD_LIBRARY_PATH`, `PROJ_DATA`, and `GDAL_DATA` to its subprocess. The R script prepends `.R-library/` while retaining the ordinary R library. Use `sh scripts/map-r.sh` rather than a bare Rscript invocation on this host.

## Outputs and evidence

- Raw source tiles: ignored `data/30daymap/2026/day02/`.
- Unsmoothed and smoothed terrain TIFFs: ignored Day02 `artifacts/`.
- Large derived contour GeoJSON and SVG: generated but ignored, reproducible from raw tiles.
- Native-R PNG, PDF and compact `provenance.R`: tracked Day02 `artifacts/`.
- Original approved palette/framing studies: `reference/`, labeled historical prototype evidence.
- Native render: projected elevation range approximately 138.727–294.149 m, complete 40 km terrain coverage, 10 m contours grouped into 15 elevation-level features over the final 24 km crop. This is not directly comparable to the Python prototype's segment count.

Day02 uses its verified committed PNG during article rendering. If the image is missing, its build chunk regenerates it from cached raw tiles. Run `render-map.R` explicitly for a forced terrain rebuild.

## Day 01: Andes earthquake points

Day01 needs only base R graphics, `jsonlite`, and `digest`; it runs with ordinary
`Rscript` and does not need the Day02 GIS runtime. Run from the repository root:

```sh
Rscript posts/2026-11-01-30daymap-01-points/render-map.R --download
Rscript tests/test-day01-map.R
quarto render posts/2026-11-01-30daymap-01-points/2026-11-01-30daymap-01-points.qmd --execute
```

The test includes a freeze check, so on a fresh checkout render before testing.
Omit `--download` once the three source files are cached in
`data/30daymap/2026/day01/`. Rendering never downloads data. The committed
`source-snapshot.json` pins the catalog bytes with SHA-256 and the coastline and land polygons to a
Natural Earth Git revision. USGS historical catalogs can change: if a new download
fails the fingerprint check, review the source revisions and refresh the snapshot,
article counts, artifacts, and tests together. The original catalog snapshot must
be retained in the local cache for exact reproduction; Git contains the recipe and
fingerprints, not the raw data. Package versions are recorded in `artifacts/provenance.R`.

The PNG is 1800 × 3000 pixels; the PDF is a vector export. Both show the same
projection and point set. Day01 is marked for publication. The legacy TidyTuesday validator looks specifically for
`figure-html/*.png`, so it reports `NO_PLOTS` for this post's `include_graphics()`
artifact. The Day01 test checks the actual PNG and executed freeze instead.

## Day 03: soil × bedrock mosaic

Native R dependencies: `sf`, `jsonlite`, `httr`, and `digest`. The separate
`tasks/30daymap-day03-r.lock` records the tested package set without activating
site-wide renv. Install with `pak::pkg_install(c("sf", "jsonlite", "httr", "digest"),
lib = ".R-library", ask = FALSE)` or restore that lockfile into `.R-library` with
`renv`. On the current Fedora 44 host, the GIS runtimes were already installed;
only the UDUNITS runtime was missing. It was downloaded with `dnf download
udunits2 --destdir .sysdeps/rpms` and the x86_64 RPM extracted using `rpm2cpio |
cpio -idm` from within `.sysdeps`. This runs no package installation scripts and
needs no sudo. `scripts/map-r.sh` scopes the local library and XML paths. Other
hosts should supply their own native GIS/UDUNITS runtimes.

From the repository root:

```sh
sh scripts/map-r.sh posts/2026-11-03-30daymap-03-polygons/acquire-data.R
sh scripts/map-r.sh posts/2026-11-03-30daymap-03-polygons/render-map.R
sh scripts/map-r.sh --quarto render posts/2026-11-03-30daymap-03-polygons/2026-11-03-30daymap-03-polygons.qmd --execute
sh scripts/map-r.sh tests/test-day03-map.R
```

Acquisition is explicit and uses ignored `data/30daymap/2026/day03/`. Raw SDA
responses and query SQL, bedrock GeoJSON, and source metadata are fingerprinted.
Changed source payloads stop rendering. Only after reviewing a source change,
use `render-map.R --snapshot --rebuild` to accept new fingerprints and rebuild;
review the article, map, and validation expectations together. Renders never
fetch source data or refresh fingerprints automatically.

`intersection.rds` is an ignored derived cache. Its signature includes the source
snapshot, preparation functions/configuration, and rock classification table; `--rebuild` forces regeneration.
The render emits jewel/earth PNG alternatives, a vector PDF, area totals by class
combination, and compact provenance. Geographic clipping and intersections use
full geometry; fine fragments are retained. The Day03 post uses the selected Earth palette and is marked for publication.

## Day 04: industrial reporting-site clusters

Dependencies are `sf`, `dbscan`, `jsonlite`, and `digest`, recorded separately in
`tasks/30daymap-day04-r.lock`. The current host reuses Day03's local GIS/UDUNITS
runtime. Install the added package explicitly with
`pak::pkg_install("dbscan", lib = ".R-library", ask = FALSE)`; nothing installs
packages during a render. Restore the Day04 lockfile into `.R-library` with renv
for the recorded R package versions.

From the repository root:

```sh
sh scripts/map-r.sh posts/2026-11-04-30daymap-04-clusters/render-map.R --download
sh scripts/map-r.sh --quarto render posts/2026-11-04-30daymap-04-clusters/2026-11-04-30daymap-04-clusters.qmd --execute
sh scripts/map-r.sh tests/test-day04-map.R
```

The explicit acquisition flag fetches missing state TRI CSV files and a pinned
Natural Earth river GeoJSON into ignored `data/30daymap/2026/day04/`. Omit it once
cached. The checked source snapshot records exact SHA-256 fingerprints. Revised
EPA state downloads require review before using `render-map.R --snapshot` to
accept new source bytes and rebuilding/reviewing counts, tests, prose, and figures.
Ordinary post execution only uses cached inputs and never updates fingerprints.

The script deduplicates chemical rows by TRI ID and combines matching FRS site
IDs only when coordinates agree. Missing FRS IDs retain their TRI keys. Original
sector labels and contributing TRI IDs are retained in `reporting-sites.csv`.
Blank coordinate datums are explicitly assumed WGS84; known NAD27/NAD83 values
would be transformed from their stated CRS. All distances use EPSG:26916.

DBSCAN uses at least four sites including the point itself, with 3/5/8 km
neighborhood comparisons. Clustering runs on the full three-state population
within 20 km of the generalized Ohio River, before applying the display crop.
The source frame and corridor are analytic choices, not physical impact zones.
Outputs are a 3000 × 3300 PNG, compact vector PDF, reporting-site CSV, neighborhood
comparison CSV, and provenance. Day04 is marked for publication.

## Day 05: who can see what (lidar intervisibility)

The post render needs only `terra`, `jsonlite`, and `digest`, the shared Day02 DEM
tile in ignored `data/30daymap/2026/day02/`, and the committed lidar reductions
(`ept-nodes.csv`, `landmark-tops.csv`, `sightline-profiles.csv`,
`landmarks.geojson`). It makes no network requests and never reads point clouds.

Rebuilding the reductions is a separate, networked step that also needs `rlas` and
`curl`:

```sh
sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/acquire-lidar.R [--refresh-landmarks]
sh scripts/map-r.sh posts/2026-11-05-30daymap-05-senses-sight/render-map.R
sh scripts/map-r.sh tests/test-day05-map.R
sh scripts/map-r.sh --quarto render posts/2026-11-05-30daymap-05-senses-sight/2026-11-05-30daymap-05-senses-sight.qmd --execute
```

Lidar comes from the USGS 3DEP Entwine (EPT) copies in the public
`usgs-lidar-public` bucket on AWS, not rockyweb LAZ tiles; rockyweb returned HTTP
429 to every client during development. Nodes cache in ignored
`data/30daymap/2026/day05/ept/` (~100 MB for the 2,518 nodes). The script records a SHA-256 manifest of
the node files in `source-snapshot.json`; a changed manifest means USGS rebuilt the
index and the matrix needs review.

`rlas` 1.9.5 builds from CRAN source and needs GDAL, PROJ, and GEOS development
files. On the Fedora 44 host, without sudo, the matching `-devel` RPMs were
extracted into ignored `.sysdeps/gdal-devel/` (`dnf download --arch=x86_64
gdal-devel-3.12.4-1.fc44 proj-devel-9.8.1-1.fc44 geos-devel-3.14.1-2.fc44`, then
`rpm2cpio | cpio -idm`). Point the `gdal-config-64` `CONFIG_LIBS`/`CONFIG_CFLAGS`
and the `geos-config` `prefix` at that directory (add `-I<dir>/usr/include` to the
GDAL cflags), and symlink `libgdal.so`, `libproj.so`, `libsqlite3.so`, `libgeos.so`,
and `libgeos_c.so` there to the system `/usr/lib64` runtimes. Then, with
`PATH=$PWD/.sysdeps/gdal-devel/usr/bin:$PATH`:

```r
install.packages("rlas", lib = ".R-library", repos = "https://cloud.r-project.org",
  configure.args = c(rlas = "--with-proj-include=<dir>/usr/include --with-proj-lib=<dir>/usr/lib64"))
```

The command sandbox used during development truncated R downloads written under
`/tmp`, so package installs and acquisition ran with
`TMPDIR=$PWD/data/30daymap/.rtmp` (ignored). On a normal shell this is unnecessary.
`lidR` is not required; it also pulls in `rgl`.
