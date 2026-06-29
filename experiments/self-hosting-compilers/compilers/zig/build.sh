#!/usr/bin/env bash
# Build the Zig compiler with NO LLVM, starting from its self-hosted-to-wasm
# form. The chain is entirely upstream's `bootstrap.c`:
#
#   stage1/zig1.wasm   (Zig compiler, self-compiled to wasm — committed here)
#     -> wasm2c        (stage1/wasm2c.c turns zig1.wasm into portable C)
#     -> zig1          (gcc builds that C; a working, if slow, Zig compiler)
#     -> zig1 compiles src/main.zig with -ofmt=c  ->  zig2.c (~187 MB of C)
#     -> gcc builds zig2.c + compiler_rt.c         ->  zig2  (the real compiler)
#
# zig2 is a full, no-LLVM Zig compiler that emits native AND wasm. See notes.md.
#
# HEAVY: ~10 min wall, ~6 GB RAM for the final gcc pass. Not part of verify.sh.
# The full source tree is too large to vendor, so we clone it at the pinned ref.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
build="$here/build"
dist="$here/dist"
CC=${CC:-cc}

mkdir -p "$dist"

if [ ! -d "$build/.git" ]; then
  echo "[zig] cloning ziglang/zig @ $ref (full tree ~370 MB; needs network) ..."
  rm -rf "$build"
  git clone --filter=blob:none https://github.com/ziglang/zig "$build"
  git -C "$build" checkout --detach "$ref"
fi

# Provenance: the committed self-hosted artifact must match the pinned tree's.
got=$(sha256sum "$build/stage1/zig1.wasm" | cut -d' ' -f1)
want=$(sha256sum "$here/zig1.wasm" | cut -d' ' -f1)
if [ "$got" != "$want" ]; then
  echo "[zig] WARNING: cloned stage1/zig1.wasm != committed zig1.wasm" >&2
  echo "       cloned=$got committed=$want" >&2
fi

cd "$build"
echo "[zig] compiling bootstrap.c"
"$CC" -O2 -o bootstrap bootstrap.c
echo "[zig] running the no-LLVM bootstrap (slow: ~10 min, ~6 GB RAM) ..."
CC="$CC" ./bootstrap

[ -x zig2 ] || { echo "[zig] bootstrap did not produce zig2" >&2; exit 1; }
cp zig2 "$dist/zig2"
cp stage1/zig1.wasm "$dist/zig1.wasm"
# zig2 locates its std/libc as lib/ next to the executable; symlink the cloned
# tree so dist/zig2 is self-contained within the repo.
ln -sfn "$build/lib" "$dist/lib"
echo "[zig] OK -> dist/zig2 ($(stat -c%s "$dist/zig2") bytes), dist/zig1.wasm"
"$dist/zig2" build-exe --help >/dev/null 2>&1 || true
echo "[zig] run compilers/zig/test.sh to exercise native + wasm codegen"
