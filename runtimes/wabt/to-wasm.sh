#!/usr/bin/env bash
# Roadmap phase 2: compile the wabt tool suite (wat2wasm, wasm2wat, wasm-objdump,
# wasm-validate, wasm-strip, wat-desugar) TO wasm with wasi-sdk. These are C++,
# but wabt builds exception-free (WITH_EXCEPTIONS=OFF), so wasi-sdk's
# no-exceptions libc++ is fine. Output: src/build.wasm/<tool> (wasm modules).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASI_SDK="$repo/tools/wasi-sdk"
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
TOOLS="wat2wasm wasm2wat wasm-objdump wasm-validate wasm-strip wat-desugar"

[ -x "$WASI_SDK/bin/clang" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
for t in cmake ninja; do command -v $t >/dev/null || { echo "[wabt] need $t"; exit 1; }; done

if [ ! -d "$src/.git" ]; then
  echo "[wabt->wasm] cloning @ $ref"
  git clone --depth 1 https://github.com/WebAssembly/wabt "$src"
  git -C "$src" fetch --depth 1 origin "$ref" && git -C "$src" checkout --detach "$ref" || true
fi
# wabt needs one third-party single-header (picosha2) that a shallow clone omits.
if [ ! -f "$src/third_party/picosha2/picosha2.h" ]; then
  mkdir -p "$src/third_party/picosha2"
  curl -sSL https://raw.githubusercontent.com/okdshin/PicoSHA2/master/picosha2.h \
    -o "$src/third_party/picosha2/picosha2.h"
fi

echo "[wabt->wasm] configuring with wasi-sdk toolchain"
rm -rf "$src/build.wasm"
cmake -S "$src" -B "$src/build.wasm" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK/share/cmake/wasi-sdk-p1.cmake" \
  -DBUILD_TESTS=OFF -DBUILD_LIBWASM=OFF -DWITH_EXCEPTIONS=OFF \
  -DCMAKE_BUILD_TYPE=Release >/dev/null

echo "[wabt->wasm] building: $TOOLS"
for t in $TOOLS; do cmake --build "$src/build.wasm" --target "$t" >/dev/null 2>&1 || echo "  WARN: $t failed"; done
echo "[wabt->wasm] OK:"
for t in $TOOLS; do [ -f "$src/build.wasm/$t" ] && echo "  $t ($(stat -c%s "$src/build.wasm/$t") bytes, $(file -b "$src/build.wasm/$t" | grep -o WebAssembly))"; done
