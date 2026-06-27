#!/usr/bin/env bash
# Build a wasm3 WASI runtime (into tools/wasm3) for running the
# compiler-as-wasm artifacts on the dev VM.
#
# Built from source because the dev VM's egress is firewalled to the GitHub
# release CDN / package registries (only `git clone` + `apt` get out).
#
# Patched: wasm3's uvwasi backend hardcodes preopens "/" and "./"; we add a
# preopen literally named "." because some guests resolve relative paths via a
# preopen of that exact name (e.g. Virgil's wasm-wasi1 runtime). Harmless to
# others.
#
# Host deps: gcc, git, and libuv1-dev (sudo apt install libuv1-dev).
set -euo pipefail
root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
tools="$root/tools"; mkdir -p "$tools"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

command -v gcc >/dev/null || { echo "ERROR: need gcc"; exit 1; }
dpkg -s libuv1-dev >/dev/null 2>&1 || { echo "ERROR: need libuv1-dev (sudo apt install libuv1-dev)"; exit 1; }

echo ">> cloning wasm3 + uvwasi"
git clone --quiet --depth 1 https://github.com/wasm3/wasm3   "$work/wasm3"
git clone --quiet --depth 1 https://github.com/nodejs/uvwasi "$work/uvwasi"

echo ">> patching wasm3 uvwasi preopens (+ \".\")"
python3 - "$work/wasm3/source/m3_api_uvwasi.c" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
assert "#define PREOPENS_COUNT  2" in s, "wasm3 layout changed; update patch"
s = s.replace("#define PREOPENS_COUNT  2", "#define PREOPENS_COUNT  3")
s = s.replace(
    '    preopens[1].mapped_path = "./";\n    preopens[1].real_path = ".";',
    '    preopens[1].mapped_path = "./";\n    preopens[1].real_path = ".";\n'
    '    preopens[2].mapped_path = ".";\n    preopens[2].real_path = ".";')
open(p, "w").write(s)
PY

echo ">> compiling tools/wasm3"
gcc -O2 -I"$work/wasm3/source" -I"$work/uvwasi/include" -Dd_m3HasUVWASI \
  "$work"/wasm3/source/*.c "$work"/uvwasi/src/*.c "$work"/wasm3/platforms/app/main.c \
  -o "$tools/wasm3" -luv -lm
"$tools/wasm3" --version | head -1
echo ">> wrote $tools/wasm3"
