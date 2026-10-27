#!/bin/sh
# Regenerates idl/ggg.js from ggg.did. DIDC defaults to a didc on PATH.
set -eu
cd "$(dirname "$0")/.."
didc="${DIDC:-didc}"
mkdir -p idl
"$didc" check ../ggg.did
"$didc" bind -t js ../ggg.did > idl/ggg.js
