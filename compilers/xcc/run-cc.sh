#!/usr/bin/env bash
# Compile a C file using xcc's cc.wasm running as wasm under tools/wasm3.
# Usage: run-cc.sh <input.c> <output.wasm>
#
# cc.wasm expects its toolchain at guest paths /usr/include and /usr/lib, and a
# writable /tmp. wasm3's uvwasi maps "/" -> cwd, so we stage that layout in a
# temp dir and run from there.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
W3="$root/tools/wasm3"
in=${1:?usage: run-cc.sh <input.c> <output.wasm>}
out=${2:?usage: run-cc.sh <input.c> <output.wasm>}

[ -x "$W3" ] || { echo "runtime missing — run scripts/build-wasm3.sh"; exit 1; }
[ -f "$here/dist/cc.wasm" ] || "$here/build.sh" >/dev/null
[ -f "$here/src/lib/wlibc.a" ] || make -C "$here/src" wcc >/dev/null 2>&1

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/usr/include" "$stage/usr/lib" "$stage/tmp"
cp -r "$here/src/include/." "$stage/usr/include/"
cp "$here/src/libsrc/_wasm/wasi.h" "$stage/usr/include/" 2>/dev/null || true
cp "$here/src/lib/"*.a "$stage/usr/lib/"
cp "$here/dist/cc.wasm" "$stage/"
cp "$in" "$stage/input.c"

( cd "$stage" && "$W3" --stack-size 4194304 cc.wasm -o /output.wasm /input.c )
cp "$stage/output.wasm" "$out"
