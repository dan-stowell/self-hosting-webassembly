#!/usr/bin/env bash
# The "no engine at all" headline, end to end, using only tcc + C:
#   1. de-virtualize cc.wasm (xcc's C->wasm compiler, archived) into native cc
#   2. native cc compiles hello.c -> hello.wasm   (a wasm compiler, no engine)
#   3. de-virtualize hello.wasm into a native binary
#   4. run it
# No wasm runtime is installed or invoked anywhere in this script.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xcc="$repo/experiments/self-hosting-compilers/compilers/xcc"
CC=${CC:-tcc}
work="$here/devirt"; mkdir -p "$work"

echo "== building w2c2 + WASI lib with $CC =="
CC="$CC" "$here/build.sh" >/dev/null
echo

# Ensure the archived xcc artifacts the demo consumes exist.
[ -f "$xcc/dist/cc.wasm" ]   || { echo "building xcc cc.wasm..."; "$xcc/build.sh" >/dev/null; }
[ -f "$xcc/src/lib/wlibc.a" ] || make -C "$xcc/src" wcc >/dev/null 2>&1

echo "== [1/4] de-virtualize cc.wasm  ->  native cc  (no engine) =="
CC="$CC" "$here/devirt.sh" "$xcc/dist/cc.wasm" "$work/cc"

echo "== [2/4] native cc compiles hello.c -> hello.wasm =="
printf '#include <stdio.h>\nint main(void){ printf("hello from a de-virtualized wasm C compiler\\n"); return 0; }\n' > "$work/hello.c"
"$work/cc" -nostdinc -isystem "$xcc/src/include" -isystem "$xcc/src/libsrc/_wasm" \
           -L "$xcc/src/lib" -o "$work/hello.wasm" "$work/hello.c"
file "$work/hello.wasm" | grep -q WebAssembly && echo "  OK: produced a real wasm module ($(wc -c < "$work/hello.wasm") bytes)"

echo "== [3/4] de-virtualize hello.wasm -> native (no engine) =="
CC="$CC" "$here/devirt.sh" "$work/hello.wasm" "$work/hello"

echo "== [4/4] run the result =="
out=$("$work/hello")
echo "  output: $out"
echo
if [ "$out" = "hello from a de-virtualized wasm C compiler" ]; then
  echo "FULL NO-ENGINE LOOP OK — tcc + C only, zero wasm runtime."
else
  echo "FAIL: unexpected output"; exit 1
fi
