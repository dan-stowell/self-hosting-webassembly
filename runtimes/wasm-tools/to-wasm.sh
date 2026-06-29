#!/usr/bin/env bash
# Roadmap phase 2: compile wasm-tools — the modern Rust wasm toolbox
# (validate, print, parse, dump, smith, component tooling, ...) — TO wasm via
# Rust's native wasm32-wasip1 target, and run it inside the tcc-built toywasm.
# Pure Rust, no native deps; cargo just targets wasip1.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
command -v cargo >/dev/null || { echo "[wasm-tools] need cargo + rustup target wasm32-wasip1"; exit 1; }
rustup target list --installed 2>/dev/null | grep -q wasm32-wasip1 || rustup target add wasm32-wasip1

if [ ! -d "$src/.git" ]; then
  echo "[wasm-tools->wasm] cloning @ $ref"
  git clone https://github.com/bytecodealliance/wasm-tools "$src"
  git -C "$src" checkout --detach "$ref" 2>/dev/null || true
fi

echo "[wasm-tools->wasm] cargo build --target wasm32-wasip1 --release --bin wasm-tools"
( cd "$src" && cargo build --target wasm32-wasip1 --release --bin wasm-tools )
out="$src/target/wasm32-wasip1/release/wasm-tools.wasm"
echo "[wasm-tools->wasm] OK: $out ($(stat -c%s "$out") bytes, $(file -b "$out" | grep -o WebAssembly))"
