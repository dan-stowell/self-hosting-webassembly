#!/usr/bin/env bash
# Roadmap phase 2: compile w2c2 (a tool that operates on wasm) TO wasm, so the
# wasm->C translator itself runs as a wasm module — e.g. inside toywasm.
# Bridge: wasi-sdk clang. Output: src/w2c2/w2c2.wasm (gitignored).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASICC="$repo/tools/wasi-sdk/bin/clang"

[ -x "$WASICC" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
[ -d "$here/src/.git" ] || "$here/build.sh" >/dev/null   # ensure the pinned clone exists

# wasi-libc has no glob(); neutralize w2c2's datasegment-cleanup #error path
# (unused for single-file translation). Idempotent.
perl -0pi -e 's/#else\n#error "Unable to find files"\n#endif/#else\n    return; while (0) {\n#endif/ unless /return; while \(0\)/' "$here/src/w2c2/main.c"

echo "[w2c2->wasm] compiling with wasi-sdk clang"
make -C "$here/src/w2c2" clean >/dev/null 2>&1 || true
make -C "$here/src/w2c2" WASI_CC="$WASICC" BUILD=release FEATURES="getopt unistd strdup" >/dev/null

out="$here/src/w2c2/w2c2.wasm"
[ -f "$out" ] || { echo "[w2c2->wasm] build produced no w2c2.wasm" >&2; exit 1; }
echo "[w2c2->wasm] OK: $out ($(stat -c%s "$out") bytes) — run demo-in-wasm.sh"
