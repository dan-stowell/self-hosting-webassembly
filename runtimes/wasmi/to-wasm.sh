#!/usr/bin/env bash
# Roadmap phase 3: compile wasmi — a Rust wasm interpreter — TO wasm via Rust's
# wasm32-wasip1 target, and run it inside the tcc-built toywasm.
#
# wasmi's stock CLI (wasmi_cli) pulls cap-std/io-extras, which need *nightly*
# Rust (#![feature(wasi_ext)]). So, like fizzy, we pair wasmi's CORE crate with
# a tiny embedder (runner/) that loads a module and runs an export — builds on
# stable. Output: runner/target/wasm32-wasip1/release/wasmi-run.wasm.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
command -v cargo >/dev/null || { echo "[wasmi] need cargo + rustup target wasm32-wasip1"; exit 1; }
rustup target list --installed 2>/dev/null | grep -q wasm32-wasip1 || rustup target add wasm32-wasip1

if [ ! -d "$src/.git" ]; then
  echo "[wasmi->wasm] cloning @ $ref"
  git clone https://github.com/wasmi-labs/wasmi "$src"
  git -C "$src" checkout --detach "$ref" 2>/dev/null || true
fi

echo "[wasmi->wasm] cargo build (embedder, wasmi core) --target wasm32-wasip1 --release"
( cd "$here/runner" && cargo build --target wasm32-wasip1 --release )
out="$here/runner/target/wasm32-wasip1/release/wasmi-run.wasm"
echo "[wasmi->wasm] OK: $out ($(stat -c%s "$out") bytes, $(file -b "$out" | grep -o WebAssembly))"
