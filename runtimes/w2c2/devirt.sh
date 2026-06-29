#!/usr/bin/env bash
# De-virtualize a WASI command module: turn any <module>.wasm into a NATIVE
# executable, with no wasm engine — w2c2 translates it to C, a tiny C compiler
# builds it, and the w2c2 WASI runtime provides the syscalls. The result IS the
# program, as ordinary machine code.
#
# Usage: devirt.sh <module.wasm> <out-binary>   (CC=tcc by default)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src="$here/src"
W2C2="$src/w2c2/w2c2"
WASI="$src/wasi"
CC=${CC:-tcc}
in=${1:?usage: devirt.sh <module.wasm> <out-binary>}
out=${2:?usage: devirt.sh <module.wasm> <out-binary>}

[ -x "$W2C2" ] || { echo "w2c2 not built — run build.sh first"; exit 1; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# 1. wasm -> C
"$W2C2" "$in" "$work/mod.c"

# 2. discover the module's symbol prefix from the generated header (<prefix>__start)
prefix=$(grep -oE '[A-Za-z_][A-Za-z0-9_]*__start' "$work/mod.h" | head -1 | sed 's/__start$//')
[ -n "$prefix" ] || { echo "no _start in $(basename "$in") — not a WASI command module"; exit 1; }

# 3. generate a generic WASI harness for that prefix
cat > "$work/harness.c" <<EOF
#include <stdio.h>
#include <stdlib.h>
#include "w2c2_base.h"
#include "wasi.h"
#include "mod.h"
void trap(Trap t) { fprintf(stderr, "TRAP: %s\n", trapDescription(t)); abort(); }
wasmMemory* wasiMemory(void* i) { return ${prefix}_memory((${prefix}Instance*)i); }
extern char** environ;
int main(int argc, char* argv[]) {
    if (!wasiInit(argc, argv, environ)) { fprintf(stderr, "WASI init failed\n"); return 1; }
    if (!wasiFileDescriptorAdd(-1, "/", NULL)) { fprintf(stderr, "preopen / failed\n"); return 1; }
    { ${prefix}Instance in; ${prefix}Instantiate(&in, NULL); ${prefix}__start(&in); ${prefix}FreeInstance(&in); }
    return 0;
}
EOF

# 4. compile + link with the tiny C compiler — no engine in the result
$CC -I"$src/w2c2" -I"$WASI" -I"$work" -O2 -c "$work/mod.c"     -o "$work/mod.o"     2>/dev/null
$CC -I"$src/w2c2" -I"$WASI" -I"$work"     -c "$work/harness.c" -o "$work/harness.o" 2>/dev/null
$CC "$work/mod.o" "$work/harness.o" -o "$out" -L"$WASI" -lw2c2wasi -lm

echo "devirt: $(basename "$in") -> $out  (prefix=$prefix, no wasm engine, built with $CC)"
