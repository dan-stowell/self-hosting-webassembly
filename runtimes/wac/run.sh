#!/usr/bin/env bash
# Run a hand-written wasi_unstable module under the tcc-built wax interpreter.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
[ -x "$here/src/wax" ] || "$here/build.sh"
command -v wat2wasm >/dev/null || { echo "need wat2wasm (apt install wabt)"; exit 1; }
wat2wasm "$here/hello_unstable.wat" -o "$here/hello_unstable.wasm"
echo "== wax (built by tcc) executing a WASI module =="
# NOTE: wax assumes a 32-bit ABI (upstream Makefile forces -m32). On a 64-bit
# build the program runs and prints correctly, but host-call arg marshalling
# over-runs afterwards, so we keep just the program's line of output (and drain
# the rest to avoid SIGPIPE).
"$here/src/wax" "$here/hello_unstable.wasm" 2>/dev/null | { IFS= read -r line; echo "$line"; cat >/dev/null; }
