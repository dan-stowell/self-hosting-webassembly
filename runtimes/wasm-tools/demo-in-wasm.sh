#!/usr/bin/env bash
# Roadmap phase 2: wasm-tools (the Rust wasm toolbox) compiled TO wasm, run
# inside the tcc-built toywasm, operating on wasm. wat2wasm.wasm (wabt, as wasm)
# assembles a module; wasm-tools.wasm then validates and prints it.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
NATIVE="$repo/runtimes/toywasm/build/toywasm"
WT="$here/src/target/wasm32-wasip1/release/wasm-tools.wasm"
WAT2WASM="$repo/runtimes/wabt/src/build.wasm/wat2wasm"

echo "== ensure tcc-built toywasm =="; [ -x "$NATIVE" ] || "$repo/runtimes/toywasm/build.sh" >/dev/null
echo "== ensure wasm-tools as wasm =="; [ -f "$WT" ] || "$here/to-wasm.sh" >/dev/null
echo "== ensure wat2wasm as wasm =="; [ -f "$WAT2WASM" ] || "$repo/runtimes/wabt/to-wasm.sh" >/dev/null
echo

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cp "$WT" "$stage/wasm-tools.wasm"; cp "$WAT2WASM" "$stage/wat2wasm"
cp "$repo/runtimes/wasm3/hello_p1.wat" "$stage/hello.wat"
cd "$stage"
# Rust/wasip1 resolves paths against preopens by prefix; map host . -> guest /.
runrust(){ "$NATIVE" --wasi --wasi-dir .::/ -- "$@"; }

echo "== [1] wat2wasm.wasm assembles hello.wasm =="
"$NATIVE" --wasi --wasi-dir . -- wat2wasm hello.wat -o hello.wasm; echo "  $(wc -c < hello.wasm) bytes"

echo "== [2] wasm-tools.wasm --version =="
runrust wasm-tools.wasm --version | sed 's/^/  /'

echo "== [3] wasm-tools.wasm validate /hello.wasm =="
if runrust wasm-tools.wasm validate /hello.wasm; then echo "  VALID"; else echo "  INVALID"; exit 1; fi

echo "== [4] wasm-tools.wasm print /hello.wasm (wasm -> wat) =="
runrust wasm-tools.wasm print /hello.wasm 2>/dev/null | grep -m1 fd_write | sed 's/^/  /'
echo
echo "PHASE 2 (wasm-tools) OK — the Rust wasm toolbox ran AS wasm in the tcc-built floor."
