#!/usr/bin/env bash
# Path B headline: a tiny C compiler builds an interpreter that HOSTS a real
# compiler. All inside the tcc-built toywasm:
#   1. host xcc's cc.wasm, compile hello.c -> hello.wasm
#   2. run hello.wasm under toywasm
# (the complement to w2c2's "no engine" de-virtualization — here the engine is
#  present, tiny, and tcc-built, and it runs current wasi_snapshot_preview1.)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xcc="$repo/experiments/self-hosting-compilers/compilers/xcc"
CC=${CC:-tcc}
TW="$here/build/toywasm"

echo "== building toywasm with $CC =="
CC="$CC" "$here/build.sh" >/dev/null
echo

[ -f "$xcc/dist/cc.wasm" ]   || { echo "building xcc cc.wasm..."; "$xcc/build.sh" >/dev/null; }
[ -f "$xcc/src/lib/wlibc.a" ] || make -C "$xcc/src" wcc >/dev/null 2>&1

# stage the guest filesystem cc.wasm expects (/usr/include, /usr/lib, /tmp)
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/usr/include" "$stage/usr/lib" "$stage/tmp"
cp -r "$xcc/src/include/." "$stage/usr/include/"
cp "$xcc/src/libsrc/_wasm/wasi.h" "$stage/usr/include/" 2>/dev/null || true
cp "$xcc/src/lib/"*.a "$stage/usr/lib/"
printf '#include <stdio.h>\nint main(void){ printf("compiled by cc.wasm, hosted in tcc-built toywasm\\n"); return 0; }\n' > "$stage/input.c"

echo "== [1/2] toywasm hosts cc.wasm: compile /input.c -> /out.wasm =="
"$TW" --wasi --wasi-dir "$stage::/" -- "$xcc/dist/cc.wasm" -o /out.wasm /input.c
file "$stage/out.wasm" | grep -q WebAssembly && echo "  OK: cc.wasm (running in toywasm) produced wasm ($(wc -c < "$stage/out.wasm") bytes)"

echo "== [2/2] run that wasm under toywasm =="
out=$("$TW" --wasi "$stage/out.wasm")
echo "  output: $out"
echo
[ "$out" = "compiled by cc.wasm, hosted in tcc-built toywasm" ] \
  && echo "PATH B OK — tcc-built interpreter hosted a real compiler, modern WASI." \
  || { echo "FAIL"; exit 1; }
