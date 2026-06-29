#!/usr/bin/env bash
# Roadmap phase 3: compile wasmtime — the Bytecode Alliance reference runtime —
# TO wasm via Rust's wasm32-wasip1 target, using its Pulley interpreter (no
# native JIT), and run it inside the tcc-built toywasm. wasmtime runs its full
# Cranelift pipeline (lowering wasm to *Pulley bytecode* rather than native
# code) AND the Pulley interpreter, all as wasm.
#
# wasip1 is an "unsupported OS" to wasmtime's sys layer, so we build the
# embedder (runner/) with the `custom-virtual-memory` feature and supply the
# platform hooks in runner/src/main.rs (malloc-backed mmap; Pulley bounds-checks
# explicitly so no signals/guard-pages/sync hooks are needed). wasmtime's own
# CLI isn't used (it needs cap-std/rustix/native OS).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
command -v cargo >/dev/null || { echo "[wasmtime] need cargo + rustup target wasm32-wasip1"; exit 1; }
rustup target list --installed 2>/dev/null | grep -q wasm32-wasip1 || rustup target add wasm32-wasip1

if [ ! -d "$src/.git" ]; then
  echo "[wasmtime->wasm] cloning @ $ref"
  git clone https://github.com/bytecodealliance/wasmtime "$src"
  git -C "$src" checkout --detach "$ref" 2>/dev/null || true
  git -C "$src" submodule update --init --depth 1 2>/dev/null || true
fi

echo "[wasmtime->wasm] cargo build (Pulley embedder) --target wasm32-wasip1 --release"
( cd "$here/runner" && cargo build --target wasm32-wasip1 --release )
out="$here/runner/target/wasm32-wasip1/release/wasmtime-run.wasm"
echo "[wasmtime->wasm] OK: $out ($(stat -c%s "$out") bytes, $(file -b "$out" | grep -o WebAssembly))"
