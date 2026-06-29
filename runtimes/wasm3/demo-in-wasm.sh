#!/usr/bin/env bash
# Roadmap phase 3: wasm3 (compiled to wasm) runs a WASI program, all inside the
# tcc-built toywasm.  native toywasm  ▷  wasm3.wasm  ▷  hello_p1.wasm
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wasm3.wasm =="; [ -f "$here/src/wasm3.wasm" ] || "$here/to-wasm.sh" >/dev/null
command -v wat2wasm >/dev/null || { echo "need wat2wasm (apt install wabt)"; exit 1; }
wat2wasm "$here/hello_p1.wat" -o "$here/hello_p1.wasm"
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$here/src/wasm3.wasm" "$stage/"; cp "$here/hello_p1.wasm" "$stage/"
cd "$stage"
echo "== native(tcc) -> wasm3.wasm -> hello_p1.wasm =="
out=$("$NATIVE" --wasi --wasi-dir . -- wasm3.wasm hello_p1.wasm 2>/dev/null)
echo "  $out"
echo
[ "$out" = "hello from wasm3, running inside tcc-built toywasm" ] \
  && echo "PHASE 3 (wasm3) OK — a second wasm runtime runs inside the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
