#!/usr/bin/env bash
# Capstone: ONE wasm guest, executed by EVERY wasm runtime in the floor —
# each runtime itself compiled to wasm and running inside the single tcc-built
# toywasm. C, C++, Go, and Rust runtimes, all as wasm, all computing fac(10).
#
# Run with no args to use whatever is already built; pass --build to build any
# missing pieces first (slow).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
NATIVE="$here/toywasm/build/toywasm"
WAT2WASM="$here/wabt/src/build.wasm/wat2wasm"
[ "${1:-}" = "--build" ] && BUILD=1 || BUILD=0

ensure(){ # ensure <file> <builder-script>
  [ -f "$1" ] && return 0
  if [ "$BUILD" = 1 ]; then "$2" >/dev/null 2>&1 || true; fi
  [ -f "$1" ]
}
[ -x "$NATIVE" ] || { echo "build the tcc-built toywasm first: runtimes/toywasm/build.sh"; exit 1; }
ensure "$WAT2WASM" "$here/wabt/to-wasm.sh" || { echo "need wabt wat2wasm.wasm"; exit 1; }

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WAT2WASM" "$stage/wat2wasm"
cat > "$stage/fac.wat" <<'WAT'
(module (func (export "fac") (param $n i32) (result i32)
  (local $acc i32) (local.set $acc (i32.const 1))
  (block $done (loop $loop
    (br_if $done (i32.lt_s (local.get $n) (i32.const 2)))
    (local.set $acc (i32.mul (local.get $acc) (local.get $n)))
    (local.set $n (i32.sub (local.get $n) (i32.const 1))) (br $loop)))
  (local.get $acc)))
WAT
( cd "$stage" && "$NATIVE" --wasi --wasi-dir . -- wat2wasm fac.wat -o fac.wasm )
echo "guest: fac.wasm ($(wc -c < "$stage/fac.wasm") bytes), computing fac(10) — expect 3628800"
echo "host:  tcc-built toywasm ($(stat -c%s "$NATIVE") bytes)"
echo

# table: label | lang | wasm-module | how-to-invoke (printf template, %s=module path)
run_one(){
  local label="$1" lang="$2" mod="$3" expect="$4"; shift 4
  if [ ! -f "$mod" ]; then printf "  %-11s %-5s  (not built)\n" "$label" "$lang"; return; fi
  cp "$mod" "$stage/rt.wasm"
  local out line
  # capture stderr too — some runtimes (e.g. wasm3) print results there.
  out=$(cd "$stage" && timeout 180 "$@" 2>&1 | tr -d '\r')
  line=$(echo "$out" | grep -m1 "$expect" || true)
  if [ -n "$line" ]; then
    printf "  %-11s %-5s  OK   %s\n" "$label" "$lang" "$line"
  else
    printf "  %-11s %-5s  FAIL %s\n" "$label" "$lang" "$(echo "${out:-<no output>}" | head -1)"
  fi
}

# wazero is a WASI-*command* runner (runs _start), not an export-caller, so it
# gets a WASI hello guest; the rest each call fac(10) and yield 3628800.
cp "$here/wasm3/hello_p1.wat" "$stage/hello.wat"
( cd "$stage" && "$NATIVE" --wasi --wasi-dir . -- wat2wasm hello.wat -o hello.wasm 2>/dev/null ) || true

echo "runtime     lang   result"
echo "-------------------------------------------"
# wasi-libc runtimes: --wasi-dir . + relative path; all compute fac(10).
run_one wasm3     C   "$here/wasm3/src/wasm3.wasm" 3628800 \
  "$NATIVE" --wasi --wasi-dir . -- rt.wasm --func fac fac.wasm 10
run_one wasm-interp C "$here/wabt/src/build.wasm/wasm-interp" 3628800 \
  "$NATIVE" --wasi --wasi-dir . -- rt.wasm --run-export=fac --argument=i32:10 fac.wasm
run_one WAMR      C   "$here/wamr/build.wasm/iwasm-run" 3628800 \
  "$NATIVE" --wasi --wasi-dir . -- rt.wasm fac.wasm fac 10
run_one fizzy     C++ "$here/fizzy/src/build.wasm/fizzy-run" 3628800 \
  "$NATIVE" --wasi --wasi-dir . -- rt.wasm fac.wasm fac 10
# Go / Rust: map host . -> guest / and use absolute guest path.
run_one wazero    Go  "$here/wazero/src/build.wasm/wazero" hello \
  "$NATIVE" --wasi --wasi-dir .::/ -- rt.wasm run /hello.wasm
run_one wasmi     Rust "$here/wasmi/runner/target/wasm32-wasip1/release/wasmi-run.wasm" 3628800 \
  "$NATIVE" --wasi --wasi-dir .::/ -- rt.wasm /fac.wasm fac 10
run_one wasmtime  Rust "$here/wasmtime/runner/target/wasm32-wasip1/release/wasmtime-run.wasm" 3628800 \
  "$NATIVE" --wasi --wasi-dir .::/ -- rt.wasm /fac.wasm fac 10
echo
echo "Every runtime above is itself wasm, running inside one tcc-built toywasm."
echo "(wazero is a WASI-command runner, so it runs a WASI 'hello' guest instead"
echo " of calling an export; the rest each compute fac(10) = 3628800.)"
