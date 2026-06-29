#!/usr/bin/env bash
# Build the Wa (凹语言) compiler AS a WebAssembly module.
#
# Wa is written in Go with no external dependencies, and already ships a
# wasip1 entry point (src/main_wasip1.go). So Go's own toolchain cross-compiles
# the whole compiler to a WASI module — no LLVM/emscripten/extra tools.
#
# Output: compilers/wa/dist/wa.wasm  — the Wa compiler as a WASI module.
# Run it (note: needs a large interpreter stack under wasm3):
#   wasm3 --stack-size 8388608 dist/wa.wasm build -o out.wasm prog.wa
#
# Host deps: Go (>= 1.17). Stdlib only, so GOPROXY=off works offline.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src="$here/src"; dist="$here/dist"; mkdir -p "$dist"
export GOPROXY=off

echo ">> building wa.wasm (GOOS=wasip1 GOARCH=wasm)"
( cd "$src" && GOOS=wasip1 GOARCH=wasm go build -o "$dist/wa.wasm" . )
echo ">> wrote $dist/wa.wasm ($(du -h "$dist/wa.wasm" | cut -f1))"
