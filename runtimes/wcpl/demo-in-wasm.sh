#!/usr/bin/env bash
# Roadmap phase 1: wcpl — a self-hosted C-to-wasm compiler, itself compiled to
# wasm — running AS wasm inside the tcc-built toywasm, compiling C to wasm.
# A tiny compiler that emits wasm, running as wasm, in a tiny-compiler-built
# runtime, producing wasm that then runs in the same floor.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built
WCPL="$here/build.wasm/wcpl.wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wcpl as wasm (self-hosted) =="; [ -f "$WCPL" ] || "$here/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WCPL" "$stage/wcpl.wasm"
cat > "$stage/hello.c" <<'EOF'
#include <stdio.h>
int main(void){ printf("hello from wcpl.wasm — a self-hosted C->wasm compiler, as wasm\n"); return 0; }
EOF
cd "$stage"

echo "== [1] wcpl.wasm compiles hello.c -> hello.wasm (inside toywasm) =="
"$NATIVE" --wasi --wasi-dir . -- wcpl.wasm -q -o hello.wasm hello.c
file hello.wasm | grep -q WebAssembly && echo "  OK ($(wc -c < hello.wasm) bytes)"

echo "== [2] run the compiler's output under toywasm =="
o=$("$NATIVE" --wasi hello.wasm 2>&1)
echo "  $o"
echo
[ "$o" = "hello from wcpl.wasm — a self-hosted C->wasm compiler, as wasm" ] \
  && echo "PHASE 1 (wcpl) OK — a self-hosted C->wasm compiler ran AS wasm and compiled C to wasm, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }

# Bonus (slow, interpreted): wcpl.wasm can compile its OWN source inside the
# floor and reproduce wcpl.wasm bit-for-bit — the self-host fixpoint, in wasm.
# Enable with WCPL_FIXPOINT=1 (can take many minutes under the interpreter).
if [ "${WCPL_FIXPOINT:-0}" = 1 ]; then
  echo; echo "== [bonus] wcpl.wasm compiles its own source -> wcpl1.wasm (fixpoint) =="
  cp "$here/src/"*.c "$here/src/"*.h "$stage/"
  "$NATIVE" --wasi --wasi-dir . -- wcpl.wasm -q -o wcpl1.wasm c.c l.c p.c w.c
  cmp "$WCPL" wcpl1.wasm && echo "  IDENTICAL — the compiler reproduced itself, as wasm, in the floor." \
                         || echo "  (output differs)"
fi
