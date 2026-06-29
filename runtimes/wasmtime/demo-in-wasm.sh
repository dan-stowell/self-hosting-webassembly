#!/usr/bin/env bash
# Roadmap phase 3: wasmtime (reference runtime, Pulley interpreter) compiled TO
# wasm, running another wasm module, INSIDE the tcc-built toywasm. The guest is
# assembled in-sandbox by wat2wasm.wasm; wasmtime-run.wasm then compiles it to
# Pulley bytecode (via Cranelift, running as wasm) and interprets it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"
WT="$here/runner/target/wasm32-wasip1/release/wasmtime-run.wasm"
WAT2WASM="$repo/runtimes/wabt/src/build.wasm/wat2wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wasmtime as wasm =="; [ -f "$WT" ] || "$here/to-wasm.sh" >/dev/null
echo "== ensure wat2wasm as wasm =="; [ -f "$WAT2WASM" ] || "$repo/runtimes/wabt/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WT" "$stage/wasmtime-run.wasm"; cp "$WAT2WASM" "$stage/wat2wasm"
cat > "$stage/fac.wat" <<'WAT'
(module (func (export "fac") (param $n i32) (result i32)
  (local $acc i32) (local.set $acc (i32.const 1))
  (block $done (loop $loop
    (br_if $done (i32.lt_s (local.get $n) (i32.const 2)))
    (local.set $acc (i32.mul (local.get $acc) (local.get $n)))
    (local.set $n (i32.sub (local.get $n) (i32.const 1))) (br $loop)))
  (local.get $acc)))
WAT
cd "$stage"

echo "== [1] wat2wasm.wasm assembles the guest (under toywasm) =="
"$NATIVE" --wasi --wasi-dir . -- wat2wasm fac.wat -o fac.wasm
echo "  guest: $(wc -c < fac.wasm) bytes"

echo "== [2] wasmtime-run.wasm compiles+runs fac(10) via Pulley (AS wasm, in toywasm) =="
o=$("$NATIVE" --wasi --wasi-dir .::/ -- wasmtime-run.wasm /fac.wasm fac 10 2>&1)
echo "  $o"
echo
[ "$o" = "fac => i32:3628800" ] \
  && echo "PHASE 3 (wasmtime) OK — the reference runtime + its Cranelift→Pulley pipeline ran AS wasm in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
