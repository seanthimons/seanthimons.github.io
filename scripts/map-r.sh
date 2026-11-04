#!/bin/sh
# Project-local GIS runtime loader. No root/system library changes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
if [ -d "$ROOT/.sysdeps/usr/lib/x86_64-linux-gnu" ]; then
  export LD_LIBRARY_PATH="$ROOT/.sysdeps/usr/lib/x86_64-linux-gnu:$ROOT/.sysdeps/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export PROJ_DATA="$ROOT/.sysdeps/usr/share/proj"
  export GDAL_DATA="$ROOT/.sysdeps/usr/share/gdal"
fi
# Map scripts prepend .R-library themselves, retaining the user's normal R library.
if [ "${1:-}" = "--quarto" ]; then
  shift
  exec quarto "$@"
fi
exec Rscript "$@"
