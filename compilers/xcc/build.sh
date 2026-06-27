#!/usr/bin/env bash
# Build the xcc C compiler AS a WebAssembly module (cc.wasm), self-hosted:
# native wcc (built with the host cc) compiles wcc's own C sources to wasm.
#
# Output: compilers/xcc/dist/cc.wasm  — a WASI module that is the C compiler.
# Run it with any WASI runtime, e.g.:  wasmtime cc.wasm -- --version
#
# Host deps: a C compiler (gcc/clang), make, and llvm-ar (Debian/Ubuntu: `llvm`).
#            No clang/node/emscripten required.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src="$here/src"
dist="$here/dist"

command -v llvm-ar >/dev/null || { echo "ERROR: llvm-ar not found (apt-get install llvm)"; exit 1; }

echo ">> building native wcc + self-hosting cc.wasm"
make -C "$src" -j"$(nproc)" wcc-gen2

mkdir -p "$dist"
cp "$src/cc.wasm" "$dist/cc.wasm"
echo ">> wrote $dist/cc.wasm ($(du -h "$dist/cc.wasm" | cut -f1))"
