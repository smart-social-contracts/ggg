#!/bin/sh
# Builds fixture/ggg_fixture.wasm and checks its interface against ggg.did.
# MOC, MOTOKO_CORE and DIDC default to the copies that ship with dfx and a didc on PATH.
set -eu
cd "$(dirname "$0")"

dfx_cache="${DFX_CACHE:-$(dfx cache show 2>/dev/null || true)}"
moc="${MOC:-$dfx_cache/moc}"
core="${MOTOKO_CORE:-$dfx_cache/core}"
didc="${DIDC:-didc}"

"$moc" --package core "$core" --idl -o ggg_fixture.did main.mo
"$moc" --package core "$core" -o ggg_fixture.wasm main.mo
"$moc" --package core "$core" -o broken.wasm broken.mo

if command -v "$didc" >/dev/null 2>&1; then
  "$didc" check ggg_fixture.did ../../ggg.did
  echo "fixture interface matches ggg.did"
else
  echo "didc not found: skipped the interface check" >&2
fi
