#!/usr/bin/env bash
# Roadmap phase 3: compile WAMR (wasm-micro-runtime) — the classic interpreter —
# TO wasm with wasi-sdk, and run it inside the tcc-built toywasm. WAMR self-hosts
# to wasm via three moves:
#   1. WAMR_BUILD_INVOKE_NATIVE_GENERAL=1 — the portable C native-call path, so
#      no per-arch assembly (invokeNative_*.s) is needed.
#   2. a minimal custom WASI platform (wasi-platform/) implementing only the
#      vmcore os_* API atop wasi-libc: malloc-backed mmap, no-op mprotect/caches,
#      single-threaded mutex stubs. No pthread/signal/socket/mmap dependencies.
#   3. WAMR_DISABLE_HW_BOUND_CHECK=1 — software bounds checks (wasm has no signals).
# Built with libc-builtin (no WASI passthrough); paired with a small embedder
# (iwasm-run.c). Output: build.wasm/iwasm-run (a wasm module).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASI_SDK="$repo/tools/wasi-sdk"
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"

[ -x "$WASI_SDK/bin/clang" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
for t in cmake ninja; do command -v $t >/dev/null || { echo "[wamr] need $t"; exit 1; }; done

if [ ! -d "$src/.git" ]; then
  echo "[wamr->wasm] cloning @ $ref"
  git clone https://github.com/bytecodealliance/wasm-micro-runtime "$src"
  git -C "$src" checkout --detach "$ref" 2>/dev/null || true
fi

# Install the custom WASI platform into the clone tree (WAMR's cmake includes it
# from core/shared/platform/<WAMR_BUILD_PLATFORM>/shared_platform.cmake).
echo "[wamr->wasm] installing wasi platform"
mkdir -p "$src/core/shared/platform/wasi"
cp "$here/wasi-platform/"* "$src/core/shared/platform/wasi/"

# pass-through wasm-opt shim (driver runs a post-link wasm-opt at -O2/-O3)
shim="$here/.shim"; mkdir -p "$shim"
printf '#!/bin/sh\nin="";out="";prev="";for a in "$@";do [ "$prev" = "-o" ]&&out="$a";case "$a" in -*) ;; *) [ -z "$in" ]&&in="$a";; esac;prev="$a";done;[ -n "$out" ]&&[ "$in" != "$out" ]&&cp "$in" "$out";exit 0\n' > "$shim/wasm-opt"
chmod +x "$shim/wasm-opt"; export PATH="$shim:$PATH"

b="$here/build.wasm"; rm -rf "$b"
echo "[wamr->wasm] configuring with wasi-sdk toolchain"
cmake -S "$here" -B "$b" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK/share/cmake/wasi-sdk-p1.cmake" \
  -DCMAKE_BUILD_TYPE=Release >/dev/null
echo "[wamr->wasm] building iwasm-run"
cmake --build "$b" >/dev/null 2>&1
echo "[wamr->wasm] OK: $b/iwasm-run ($(stat -c%s "$b/iwasm-run") bytes, $(file -b "$b/iwasm-run" | grep -o WebAssembly))"
