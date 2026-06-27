#!/usr/bin/env bash
# Compile a TS/AS file using the SELF-HOSTED AssemblyScript compiler — i.e. asc
# running as the wasm module it compiled itself into (`--wasm <loader>` makes the
# CLI load the wasm-built compiler instead of the JS one).
#
# Usage: run-asc.sh <in.ts> <out.wasm>
#
# The wasm compiler runs in place (its loader resolves the sibling
# assemblyscript.release.wasm and the binaryen wasm from node_modules). Run
# compilers/assemblyscript/build.sh first.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
for n in "$root"/tools/node-v2*/bin; do [ -d "$n" ] && PATH="$n:$PATH"; done
export PATH

in=${1:?usage: run-asc.sh <in.ts> <out.wasm>}
out=${2:?usage: run-asc.sh <in.ts> <out.wasm>}
loader="$here/src/build/assemblyscript.release.js"
[ -f "$loader" ] || { echo "build first: compilers/assemblyscript/build.sh"; exit 1; }

node "$here/src/bin/asc" "$in" --wasm "$loader" -o "$out" -O
