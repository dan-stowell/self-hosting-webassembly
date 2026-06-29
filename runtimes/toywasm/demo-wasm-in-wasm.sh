#!/usr/bin/env bash
# Roadmap phase 3 headline: a wasm runtime running inside a wasm runtime that a
# tiny compiler built.
#   native toywasm  = built by tcc (Path B)
#   toywasm.wasm    = toywasm compiled to wasm by wasi-sdk
# We nest them and run a real program at the bottom, up to 3 levels deep.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$here/build/toywasm"                 # tcc-built
TWWASM="$here/src/build.wasm/toywasm"        # wasi-sdk-built

echo "== ensure tcc-built native toywasm =="; [ -x "$NATIVE" ] || "$here/build.sh" >/dev/null
echo "== ensure toywasm.wasm =="; [ -f "$TWWASM" ] || "$here/to-wasm.sh" >/dev/null
# a real program to run at the bottom of the stack
hello="$repo/runtimes/w2c2/devirt/hello.wasm"
[ -f "$hello" ] || { "$repo/runtimes/w2c2/demo.sh" >/dev/null 2>&1; }
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$TWWASM" "$stage/toywasm.wasm"; cp "$hello" "$stage/hello.wasm"
cd "$stage"
fail=0
echo "== [1] toywasm-in-toywasm: native(tcc) -> toywasm.wasm --version =="
v=$("$NATIVE" --wasi --wasi-dir . -- toywasm.wasm --version 2>/dev/null )
echo "  $v"; [[ "$v" == toywasm* ]] || fail=1

echo "== [2] wasm-on-wasm runs a real program: native -> toywasm.wasm -> hello.wasm =="
o2=$("$NATIVE" --wasi --wasi-dir . -- toywasm.wasm --wasi --wasi-dir . -- hello.wasm 2>/dev/null )
echo "  $o2"; [ "$o2" = "hello from a de-virtualized wasm C compiler" ] || fail=1

echo "== [3] three deep: native -> toywasm.wasm -> toywasm.wasm -> hello.wasm =="
o3=$("$NATIVE" --wasi --wasi-dir . -- toywasm.wasm --wasi --wasi-dir . -- toywasm.wasm --wasi --wasi-dir . -- hello.wasm 2>/dev/null )
echo "  $o3"; [ "$o3" = "hello from a de-virtualized wasm C compiler" ] || fail=1

echo
[ "$fail" -eq 0 ] && echo "PHASE 3 OK — a wasm runtime runs inside a tcc-built wasm runtime, nested." \
                  || { echo "FAIL"; exit 1; }
