#!/usr/bin/env Rscript
# Explicit opt-in bootstrap. No sudo, system install, package maintainer scripts,
# Python, or automatic execution during map rendering.
stopifnot(file.exists(".gitignore"))
dir.create(".R-library", showWarnings = FALSE)
options(pak.sysreqs = FALSE, Ncpus = 2)
Sys.setenv(PKG_SYSREQS = "false")
if (!requireNamespace("pak", quietly = TRUE)) stop("Install pak first.")
pak::pkg_install(c("terra", "sf"), lib = ".R-library", ask = FALSE)
if (!identical(Sys.info()[["sysname"]], "Linux")) quit(status = 0)
os <- readLines("/etc/os-release", warn = FALSE)
if (!all(c('ID=debian', 'VERSION_ID="13"') %in% os))
  stop("The local runtime extraction recipe is Debian 13-specific; use native GIS runtimes on this platform.")
requested <- c("libgdal36", "libproj25", "libgeos-c1t64", "libudunits2-0")
plan <- system2("apt-get", c("-s", "--no-install-recommends", "install", requested), stdout = TRUE)
if (!is.null(attr(plan, "status"))) stop("apt simulation failed")
# Only the missing packages. Extraction needs no root and runs no postinst scripts.
packages <- unique(sub("^Inst ([^ ]+).*", "\\1", grep("^Inst ", plan, value = TRUE)))
dir.create(".sysdeps/debs", recursive = TRUE, showWarnings = FALSE)
root <- normalizePath(".sysdeps")
writeLines(plan, file.path(root, "apt-plan.txt"))
if (length(packages)) {
  old <- setwd(file.path(root, "debs"))
  status <- system2("apt-get", c("download", packages))
  setwd(old)
  if (status != 0L) stop("Runtime package download failed")
}
for (deb in list.files(file.path(root, "debs"), pattern = "\\.deb$", full.names = TRUE)) {
  if (system2("dpkg-deb", c("-x", shQuote(deb), shQuote(root))) != 0L) stop("Extraction failed: ", deb)
}
writeLines(packages, file.path(root, "runtime-packages.txt"))
cat("Project-local installation complete. Use scripts/map-r.sh to run R with local runtimes.\n")
