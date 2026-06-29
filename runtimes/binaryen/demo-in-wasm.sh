#!/usr/bin/env bash
# Roadmap phase 2: binaryen (wasm-opt / wasm-as / wasm-dis), compiled TO wasm
# WITH C++ exceptions, running AS wasm inside the tcc-built toywasm, operating on
# wasm. This is the one we were "blocked" on — it works because wasi-sdk 33's
# eh/ multilib gives an exception-enabled libc++ and toywasm implements the
# standardized exception-handling proposal (try_table).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"     # tcc-built, EH enabled
B="$here/src/build.wasm/bin"

echo "== ensure EH-enabled tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure binaryen tools as wasm =="; [ -f "$B/wasm-opt" ] || "$here/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$B/wasm-opt" "$B/wasm-as" "$B/wasm-dis" "$stage/" 2>/dev/null || cp "$B/wasm-opt" "$stage/"
cp "$repo/runtimes/wasm3/hello_p1.wat" "$stage/hello.wat"
cd "$stage"
run(){ "$NATIVE" --wasi --wasi-dir . -- "$@"; }

echo "== [0] wasm-opt.wasm --version (C++ exceptions live, inside toywasm) =="
run wasm-opt --version | sed 's/^/  /'

echo "== [1] wasm-as.wasm: hello.wat -> hello.wasm =="
run wasm-as hello.wat -o hello.wasm
file hello.wasm | grep -q WebAssembly && echo "  OK ($(wc -c < hello.wasm) bytes)"

echo "== [2] wasm-opt.wasm -O3: hello.wasm -> hello.opt.wasm =="
run wasm-opt -O3 hello.wasm -o hello.opt.wasm
file hello.opt.wasm | grep -q WebAssembly && echo "  OK ($(wc -c < hello.opt.wasm) bytes)"

echo "== [3] wasm-dis.wasm: hello.opt.wasm -> text =="
run wasm-dis hello.opt.wasm -o hello.opt.wat
grep -q fd_write hello.opt.wat && echo "  OK (disassembled back to text)"

echo "== [4] run the optimized module under toywasm =="
o=$("$NATIVE" --wasi hello.opt.wasm 2>/dev/null)
echo "  $o"
echo
[ "$o" = "hello from wasm3, running inside tcc-built toywasm" ] \
  && echo "PHASE 2 (binaryen) OK — wasm-opt/as/dis ran as wasm, with C++ exceptions, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
