#!/usr/bin/env bash
# Roadmap phase 3: compile toywasm itself TO wasm (wasm-in-wasm). Uses toywasm's
# own build-wasm32-wasi.sh, pointed at our local wasi-sdk. Output:
# src/build.wasm/toywasm (a 910 KB wasm module — the runtime, as wasm).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASI_SDK_DIR="$repo/tools/wasi-sdk"

[ -x "$WASI_SDK_DIR/bin/clang" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
[ -d "$here/src/.git" ] || "$here/build.sh" >/dev/null   # ensure the pinned clone

echo "[toywasm->wasm] building with wasi-sdk (threads/tests off)"
( cd "$here/src" && WASI_SDK_DIR="$WASI_SDK_DIR" BUILD_DIR=build.wasm \
    EXTRA_CMAKE_OPTIONS="-DTOYWASM_ENABLE_WASM_THREADS=OFF -DBUILD_TESTING=OFF" \
    ./build-wasm32-wasi.sh >/dev/null 2>&1 )

out="$here/src/build.wasm/toywasm"
[ -f "$out" ] || { echo "[toywasm->wasm] no toywasm.wasm produced" >&2; exit 1; }
echo "[toywasm->wasm] OK: $out ($(stat -c%s "$out") bytes) — run demo-wasm-in-wasm.sh"
