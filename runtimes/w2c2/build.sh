#!/usr/bin/env bash
# Build the w2c2 wasm->C translator AND its WASI runtime lib with a TINY C
# compiler (tcc by default). This is the "no engine at all" floor: the only
# thing you need to run WebAssembly is a C compiler.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
CC=${CC:-tcc}

if [ ! -d "$src/.git" ]; then
  echo "[w2c2] cloning @ $ref (needs network)"
  rm -rf "$src"
  git clone https://github.com/turbolent/w2c2 "$src"
  git -C "$src" checkout --detach "$ref"
fi

command -v "$CC" >/dev/null || { echo "[w2c2] '$CC' not found (apt install tcc)"; exit 1; }

# The translator. Drop the pthreads feature (tcc-unfriendly); the rest of the
# default features are plain libc and build fine under tcc.
echo "[w2c2] building translator with $CC (no threads)"
make -C "$src/w2c2" clean >/dev/null 2>&1 || true
make -C "$src/w2c2" CC="$CC" BUILD=release \
  FEATURES="getopt unistd libgen strdup glob" >/dev/null

# The WASI host runtime, linked into each de-virtualized binary.
echo "[w2c2] building WASI runtime lib with $CC (no threads)"
make -C "$src/wasi" clean >/dev/null 2>&1 || true
make -C "$src/wasi" CC="$CC" BUILD=release \
  FEATURES="unistd sysuio systime sysresource strndup fcntl timespec lstat getentropy" >/dev/null

echo "[w2c2] OK"
echo "       translator : $src/w2c2/w2c2"
echo "       wasi lib    : $src/wasi/libw2c2wasi.a"
echo "       (both built with $($CC -v 2>&1 | head -1))"
