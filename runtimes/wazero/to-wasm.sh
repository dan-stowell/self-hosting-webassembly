#!/usr/bin/env bash
# Roadmap phase 3: compile wazero — a pure-Go WebAssembly runtime — TO wasm via
# Go's native wasip1 target, and run it inside the tcc-built toywasm. wazero's
# optimizing backend emits native machine code (no good inside wasm), but it
# transparently falls back to its INTERPRETER when the host arch has no
# compiler, so wazero.wasm runs guests by interpreting them. A Go runtime, as
# wasm, running wasm.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
command -v go >/dev/null || { echo "[wazero] need go (wasip1 target)"; exit 1; }

if [ ! -d "$src/.git" ]; then
  echo "[wazero->wasm] cloning @ $ref"
  git clone https://github.com/tetratelabs/wazero "$src"
  git -C "$src" checkout --detach "$ref"
fi

out="$src/build.wasm"; mkdir -p "$out"
echo "[wazero->wasm] go build GOOS=wasip1 GOARCH=wasm ./cmd/wazero"
( cd "$src" && GOOS=wasip1 GOARCH=wasm GOFLAGS=-mod=mod go build -o "$out/wazero" ./cmd/wazero )
echo "[wazero->wasm] OK: $out/wazero ($(stat -c%s "$out/wazero") bytes, $(file -b "$out/wazero" | grep -o WebAssembly))"
