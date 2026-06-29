#!/usr/bin/env bash
# Roadmap phase 3: wasmi — a Rust wasm interpreter — compiled TO wasm and run
# inside the tcc-built toywasm, executing a guest module. A guest is assembled
# in-sandbox by wat2wasm.wasm, then run by wasmi-run.wasm (a libwasmi embedder).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"
WR="$here/runner/target/wasm32-wasip1/release/wasmi-run.wasm"
WAT2WASM="$repo/runtimes/wabt/src/build.wasm/wat2wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wasmi as wasm =="; [ -f "$WR" ] || "$here/to-wasm.sh" >/dev/null
echo "== ensure wat2wasm as wasm =="; [ -f "$WAT2WASM" ] || "$repo/runtimes/wabt/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WR" "$stage/wasmi-run.wasm"; cp "$WAT2WASM" "$stage/wat2wasm"
cat > "$stage/fac.wat" <<'EOF'
(module (func (export "fac") (param $n i32) (result i32)
  (local $acc i32) (local.set $acc (i32.const 1))
  (block $done (loop $loop
    (br_if $done (i32.lt_s (local.get $n) (i32.const 2)))
    (local.set $acc (i32.mul (local.get $acc) (local.get $n)))
    (local.set $n (i32.sub (local.get $n) (i32.const 1))) (br $loop)))
  (local.get $acc)))
EOF
cd "$stage"

echo "== [1] wat2wasm.wasm assembles the guest (under toywasm) =="
"$NATIVE" --wasi --wasi-dir . -- wat2wasm fac.wat -o fac.wasm
echo "  guest: $(wc -c < fac.wasm) bytes"

echo "== [2] wasmi-run.wasm executes fac(10) (Rust interpreter, AS wasm, in toywasm) =="
# Rust/wasip1 resolves paths against preopens by prefix; map host . -> guest /.
o=$("$NATIVE" --wasi --wasi-dir .::/ -- wasmi-run.wasm /fac.wasm fac 10 2>&1)
echo "  $o"
echo
[ "$o" = "fac => i32:3628800" ] \
  && echo "PHASE 3 (wasmi) OK — a Rust wasm interpreter ran AS wasm, executing wasm, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
