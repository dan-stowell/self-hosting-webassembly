#!/usr/bin/env bash
# Roadmap phase 2, end to end: a wasm tool, operating on wasm, running AS wasm,
# inside a wasm runtime that a tiny compiler built.
#   - toywasm: built by tcc (Path B)
#   - w2c2.wasm: w2c2 compiled to wasm by wasi-sdk
#   - it translates a .wasm module to C, all inside the sandbox
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
TW="$repo/runtimes/toywasm/build/toywasm"
W2C2WASM="$here/src/w2c2/w2c2.wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$TW" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure w2c2.wasm =="; [ -f "$W2C2WASM" ] || "$here/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$here/src/examples/fac/fac.wasm" "$stage/fac.wasm"
echo "== w2c2.wasm (in tcc-built toywasm) translates fac.wasm -> fac.c =="
"$TW" --wasi --wasi-dir "$stage::/" -- "$W2C2WASM" /fac.wasm /fac.c
if [ -s "$stage/fac.c" ] && grep -q "fac_fac" "$stage/fac.c"; then
  echo "  OK: generated $(wc -c < "$stage/fac.c")-byte C containing fac_fac()"
  echo
  echo "PHASE 2 OK — a wasm tool ran as wasm, in a tcc-built runtime, and emitted C."
else
  echo "FAIL: no valid C produced"; exit 1
fi
