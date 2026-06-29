#!/usr/bin/env bash
# Roadmap phase 3: fizzy — a fast C++ wasm interpreter — compiled TO wasm (with
# C++ exceptions, via the eh/ multilib) and run inside the tcc-built toywasm.
# A guest is assembled in-sandbox by wat2wasm.wasm, then executed by
# fizzy-run.wasm (a tiny libfizzy C-API embedder). Interpreter-inside-interpreter.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"   # tcc-built, EH enabled
FR="$here/src/build.wasm/fizzy-run"
WAT2WASM="$repo/runtimes/wabt/src/build.wasm/wat2wasm"

echo "== ensure EH-enabled tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure fizzy as wasm =="; [ -f "$FR" ] || "$here/to-wasm.sh" >/dev/null
echo "== ensure wat2wasm as wasm =="; [ -f "$WAT2WASM" ] || "$repo/runtimes/wabt/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$FR" "$stage/fizzy-run.wasm"; cp "$WAT2WASM" "$stage/wat2wasm"
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

echo "== [2] fizzy-run.wasm executes fac(10) (C++ interpreter, AS wasm, in toywasm) =="
o=$("$NATIVE" --wasi --wasi-dir . -- fizzy-run.wasm fac.wasm fac 10 2>&1)
echo "  $o"
echo
[ "$o" = "fac => i32:3628800" ] \
  && echo "PHASE 3 (fizzy) OK — a C++ wasm interpreter ran AS wasm, executing wasm, in the tcc-built floor." \
  || { echo "FAIL"; exit 1; }
