#!/bin/sh
# Regenerates idl/ from the standards' .did files. DIDC defaults to a didc on PATH.
set -eu
cd "$(dirname "$0")/.."
didc="${DIDC:-didc}"
mkdir -p idl
for n in 1 2; do
  "$didc" check "../standards/GGG-$n.did"
  "$didc" bind -t js "../standards/GGG-$n.did" > "idl/ggg$n.js"
done
