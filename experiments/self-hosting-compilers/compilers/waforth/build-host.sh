#!/usr/bin/env bash
# Build WAForth's standalone REPL host (native binary that hosts waforth_core.wasm).
# The Forth interpreter+compiler runs AS wasm inside; this host only provides I/O
# and the dynamic module `load` import (via the wasmtime C-API). It lets you
# actually run the wasm-resident compiler:
#
#   echo ': SQ DUP * ; 7 SQ .' | dist/waforth      # -> 49
#
# Output: compilers/waforth/dist/waforth
# Host deps: gcc, make, wat2wasm; downloads the wasmtime v18 C-API (needs network).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
sa="$here/src/src/standalone"; dist="$here/dist"; mkdir -p "$dist"

if ! ls -d "$sa"/wasmtime-*-c-api >/dev/null 2>&1; then
  echo ">> fetching wasmtime C-API"
  make -C "$sa" install-deps
fi
echo ">> building host"
make -C "$sa"
cp "$sa/waforth" "$dist/waforth"
echo ">> wrote $dist/waforth (Forth REPL; the compiler runs as wasm)"
