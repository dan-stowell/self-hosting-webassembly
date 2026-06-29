#!/usr/bin/env bash
# Roadmap phase 2: the wabt wasm toolbox, running AS wasm inside the tcc-built
# toywasm, operating on wasm. Round-trips a module: wat -> wasm (wat2wasm.wasm)
# -> wat (wasm2wat.wasm), inspects it (wasm-objdump.wasm), and runs the result.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built
B="$here/src/build.wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wabt tools as wasm =="; [ -f "$B/wat2wasm" ] || "$here/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$B/wat2wasm" "$B/wasm2wat" "$B/wasm-objdump" "$stage/"
cp "$repo/runtimes/wasm3/hello_p1.wat" "$stage/hello.wat"
cd "$stage"
run(){ "$NATIVE" --wasi --wasi-dir . -- "$@"; }

echo "== [1] wat2wasm.wasm: hello.wat -> hello.wasm =="
run wat2wasm hello.wat -o hello.wasm
file hello.wasm | grep -q WebAssembly && echo "  OK ($(wc -c < hello.wasm) bytes)"

echo "== [2] wasm2wat.wasm: hello.wasm -> hello2.wat =="
run wasm2wat hello.wasm -o hello2.wat
grep -q fd_write hello2.wat && echo "  OK (round-tripped back to text)"

echo "== [3] wasm-objdump.wasm -x hello.wasm (headers) =="
run wasm-objdump -x hello.wasm 2>/dev/null | grep -iE "Import|Export|fd_write" | head -3 | sed 's/^/  /'

echo "== [4] run the assembled module under toywasm =="
o=$("$NATIVE" --wasi hello.wasm 2>/dev/null)
echo "  $o"
echo
[ "$o" = "hello from wasm3, running inside tcc-built toywasm" ] \
  && echo "PHASE 2 (wabt) OK — the wasm toolbox ran as wasm, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
