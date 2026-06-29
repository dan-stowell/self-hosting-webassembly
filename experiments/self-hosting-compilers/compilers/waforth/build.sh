#!/usr/bin/env bash
# Assemble WAForth's hand-written core into a WebAssembly module.
#
# WAForth's Forth interpreter+compiler is written directly in WebAssembly text
# (src/src/waforth.wat, ~3300 lines). It emits wasm at RUNTIME from inside the
# module: compiling a Forth word builds a fresh wasm module in linear memory and
# asks the host to instantiate it (the `shell.load` import). So the compiler
# already lives in wasm — this just assembles the .wat to a .wasm binary.
#
# Output: compilers/waforth/dist/waforth.wasm
# To actually RUN it you need a host implementing 6 imports
# (shell.emit/read/key/random/load/call); upstream ships a C host in
# src/src/standalone/ (Wasmtime C-API) and a web host in src/src/web/.
#
# Host deps: wat2wasm (Debian/Ubuntu: `apt install wabt`).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src="$here/src"; dist="$here/dist"; mkdir -p "$dist"

echo ">> assembling waforth.wat -> waforth.wasm"
wat2wasm "$src/src/waforth.wat" -o "$dist/waforth.wasm"
echo ">> wrote $dist/waforth.wasm ($(du -h "$dist/waforth.wasm" | cut -f1))"
