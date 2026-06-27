#!/usr/bin/env bash
# Verify Schism self-hosts to wasm.
#
# schism-stage0.wasm (committed) is the Schism compiler (a subset of R6RS Scheme)
# compiled to a wasm module. The bootstrap runs it under Node's WASM engine to
# compile Schism's own source (schism/compiler.ss) -> stage1 -> stage2, proving
# the self-hosting fixed point.
#
# Requires a PERIOD-CORRECT Node 12: the 2019-era wasm encodings (ref.null/anyref)
# and the --experimental-wasm-* flags it uses don't work on modern V8. A pinned
# Node 12 is expected in tools/ (download: nodejs.org/dist/v12.22.12/).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
src="$here/src"

N12=$(ls -d "$root"/tools/node-v12*/bin/node 2>/dev/null | head -1)
[ -x "$N12" ] || { echo "ERROR: need Node 12 in tools/ (nodejs.org/dist/v12.22.12)"; exit 1; }

cd "$src"
out=$("$N12" --experimental-modules --experimental-wasm-anyref --experimental-wasm-return-call run-tests.mjs 2>&1) || true
echo "$out" | tail -4
if echo "$out" | grep -q "stage2 succeeded"; then
  echo ">> self-host OK: stage0.wasm compiled compiler.ss through stage1 -> stage2"
else
  echo ">> self-host FAILED"; exit 1
fi
