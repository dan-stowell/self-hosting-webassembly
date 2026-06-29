#!/usr/bin/env bash
# Roadmap: two more wabt tools as wasm, in the tcc-built toywasm.
#  - wasm-interp: a WASM INTERPRETER running AS wasm (a runtime inside the
#    runtime — phase 3, reached via the phase-2 wabt build).
#  - wasm2c: another wasm->C translator (like w2c2), running AS wasm.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built
B="$here/src/build.wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wabt tools as wasm =="; [ -f "$B/wasm-interp" ] || "$here/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$B/wat2wasm" "$B/wasm-interp" "$B/wasm2c" "$stage/"
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
run(){ "$NATIVE" --wasi --wasi-dir . -- "$@"; }

echo "== [1] wat2wasm.wasm: fac.wat -> fac.wasm =="
run wat2wasm fac.wat -o fac.wasm; echo "  OK ($(wc -c < fac.wasm) bytes)"

echo "== [2] wasm-interp.wasm: a wasm interpreter, AS wasm, runs fac(10) =="
out=$(run wasm-interp -r fac -a i32:10 fac.wasm 2>&1); echo "  $out"

echo "== [3] wasm2c.wasm: fac.wasm -> fac.c =="
run wasm2c fac.wasm -o fac.c --module-name=fac
grep -qE "w2c_fac" fac.c && echo "  OK: emitted C ($(wc -l < fac.c) lines)"
echo
[ "$out" = "fac(i32:10) => i32:3628800" ] \
  && echo "OK — a wasm interpreter and a wasm->C translator both ran AS wasm in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
