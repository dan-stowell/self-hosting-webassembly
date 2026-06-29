#!/usr/bin/env bash
# Roadmap phase 3: wazero (a pure-Go wasm runtime) compiled TO wasm, running
# another wasm module, all INSIDE the tcc-built toywasm. The guest is even
# assembled in-sandbox by wat2wasm.wasm (wabt, as wasm). So: tcc-built toywasm
# → wazero.wasm (Go runtime) → a guest module — wasm all the way down, across
# three language ecosystems (C floor, Go runtime, the guest).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built
WAZERO="$here/src/build.wasm/wazero"
WAT2WASM="$repo/runtimes/wabt/src/build.wasm/wat2wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wazero as wasm =="; [ -f "$WAZERO" ] || "$here/to-wasm.sh" >/dev/null
echo "== ensure wat2wasm as wasm =="; [ -f "$WAT2WASM" ] || "$repo/runtimes/wabt/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WAZERO" "$stage/wazero.wasm"; cp "$WAT2WASM" "$stage/wat2wasm"
cp "$repo/runtimes/wasm3/hello_p1.wat" "$stage/hello.wat"
cd "$stage"

echo "== [1] wat2wasm.wasm assembles the guest (under toywasm) =="
"$NATIVE" --wasi --wasi-dir . -- wat2wasm hello.wat -o hello.wasm
echo "  guest: $(wc -c < hello.wasm) bytes"

echo "== [2] wazero.wasm runs the guest (Go runtime as wasm, in toywasm) =="
# Go's wasip1 resolves paths against preopens by prefix; map host . -> guest /.
o=$("$NATIVE" --wasi --wasi-dir .::/ -- wazero.wasm run /hello.wasm 2>&1)
echo "  $o"
echo
[ "$o" = "hello from wasm3, running inside tcc-built toywasm" ] \
  && echo "PHASE 3 (wazero) OK — a Go wasm runtime ran AS wasm, executing wasm, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
