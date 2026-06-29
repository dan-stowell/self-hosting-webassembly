#!/usr/bin/env bash
# Roadmap phase 1: a tiny SELF-HOSTED C-to-WebAssembly compiler, compiled to
# wasm BY ITSELF, then run as wasm to compile C in the tcc-built toywasm.
#
# wcpl is a standalone C-subset compiler+linker+libc that targets WASM/WASI.
# Steps:
#   1. build wcpl natively with any cc (bootstrap seed).
#   2. use that native wcpl to compile wcpl's own source -> wcpl.wasm (self-host).
# Output: build.wasm/wcpl.wasm. No wasi-sdk needed — wcpl is its own toolchain.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
CC=${CC:-cc}

if [ ! -d "$src/.git" ]; then
  echo "[wcpl->wasm] cloning @ $ref"
  git clone https://github.com/false-schemers/wcpl "$src"
  git -C "$src" checkout --detach "$ref" 2>/dev/null || true
fi

out="$here/build.wasm"; mkdir -p "$out"
echo "[wcpl->wasm] 1/2 building native wcpl seed with $CC"
"$CC" -O2 -o "$out/wcpl.native" "$src"/c.c "$src"/l.c "$src"/p.c "$src"/w.c

echo "[wcpl->wasm] 2/2 self-hosting: native wcpl compiles wcpl -> wcpl.wasm"
( cd "$src" && "$out/wcpl.native" -q -o "$out/wcpl.wasm" c.c l.c p.c w.c )
echo "[wcpl->wasm] OK: $out/wcpl.wasm ($(stat -c%s "$out/wcpl.wasm") bytes, $(file -b "$out/wcpl.wasm" | grep -o WebAssembly))"
