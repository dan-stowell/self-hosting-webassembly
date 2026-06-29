#!/usr/bin/env bash
# Path A: build the smallest WebAssembly interpreter (kanaka's `wax`, the
# minimal WASI variant of wac) with a TINY C compiler (tcc by default).
#
# Three tcc-gap workarounds are needed (all documented in notes.md):
#   1. guard the editline/readline include (wax has no REPL, needs no readline)
#   2. -include a shim for __builtin_clz/ctz/popcount (tcc 0.9.27 lacks them)
#   3. -rdynamic, so wac's dlsym-based host-import resolution can find the
#      WASI functions in the binary's dynamic symbol table
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
CC=${CC:-tcc}

if [ ! -d "$src/.git" ]; then
  echo "[wac] cloning @ $ref"
  rm -rf "$src"; git clone https://github.com/kanaka/wac "$src"
  git -C "$src" checkout --detach "$ref"
fi
command -v "$CC" >/dev/null || { echo "[wac] '$CC' not found (apt install tcc)"; exit 1; }

# (1) Only the REPL (wac.c) uses readline; guard the include so wax needs none.
perl -0pi -e 's/#else\n    #include <editline\/readline.h>/#elif !defined(NO_READLINE)\n    #include <editline\/readline.h>/ unless /defined\(NO_READLINE\)/' "$src/platform.h"

echo "[wac] building wax with $CC"
( cd "$src" && "$CC" -rdynamic -std=gnu99 -DPLATFORM=1 -DNO_READLINE \
    -include "$here/tcc_builtins.h" \
    util.c thunk.c platform_libc.c wa.c wasi.c wax.c -o wax -lm -ldl )

echo "[wac] OK: $src/wax ($(stat -c%s "$src/wax") bytes, built with $($CC -v 2>&1 | head -1))"
echo "[wac] demo: ./run.sh   (runs a hand-written wasi_unstable hello under wax)"
