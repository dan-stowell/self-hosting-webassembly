#!/usr/bin/env bash
# Path B: build toywasm — a small, modern-WASI pure interpreter — with a TINY C
# compiler (tcc by default). cmake/ninja only orchestrate; every .c is compiled
# by tcc. Threads off (avoids the _Atomic path); unit tests off (avoids cmocka).
#
# Unlike wac/wax (Path A), toywasm speaks wasi_snapshot_preview1 and has real
# directory-mapped WASI, so it can HOST a current toolchain — see demo.sh.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
build="$here/build"
CC=${CC:-tcc}

if [ ! -d "$src/.git" ]; then
  echo "[toywasm] cloning @ $ref"
  rm -rf "$src"; git clone https://github.com/yamt/toywasm "$src"
  git -C "$src" checkout --detach "$ref"
fi
for t in "$CC" cmake ninja; do command -v "$t" >/dev/null || { echo "[toywasm] need '$t'"; exit 1; }; done

echo "[toywasm] configuring (CC=$CC, threads off, tests off)"
rm -rf "$build"; mkdir -p "$build"
cmake -S "$src" -B "$build" -G Ninja \
  -DCMAKE_C_COMPILER="$CC" \
  -DTOYWASM_ENABLE_WASM_THREADS=OFF \
  -DTOYWASM_ENABLE_WASM_EXCEPTION_HANDLING=ON \
  -DTOYWASM_BUILD_UNITTEST=OFF -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release >/dev/null

echo "[toywasm] building with $CC"
ninja -C "$build" toywasm >/dev/null

echo "[toywasm] OK: $build/toywasm ($(stat -c%s "$build/toywasm") bytes, C compiled by $($CC -v 2>&1 | head -1))"
