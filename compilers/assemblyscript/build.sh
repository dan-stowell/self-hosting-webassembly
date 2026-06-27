#!/usr/bin/env bash
# Build the AssemblyScript compiler (asc) AS a WebAssembly module.
#
# asc is written in "portable AssemblyScript" (a TS subset) and is self-hosting:
# the JS build of asc compiles asc's own source to build/assemblyscript.release.wasm,
# which is the compiler as a wasm module. Its backend is Binaryen, itself shipped
# as wasm (the `binaryen` npm package) — there is NO LLVM and no native code.
#
# Output: compilers/assemblyscript/dist/asc.wasm        (the compiler as wasm)
#         compilers/assemblyscript/dist/asc.wasm.js     (JS loader for it)
# Use it:  node src/bin/asc <in.ts> --wasm dist/asc.wasm.js -o out.wasm
#
# Host deps: Node >= 20.19 (pinned copy in tools/ is preferred) + npm.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
src="$here/src"; dist="$here/dist"; mkdir -p "$dist"

for n in "$root"/tools/node-v*/bin; do [ -d "$n" ] && PATH="$n:$PATH"; done
export PATH
command -v node >/dev/null || { echo "ERROR: need Node >= 20.19 (see tools/)"; exit 1; }

cd "$src"
[ -d node_modules ] || npm ci
npm run build            # dist/asc.js (the JS compiler bundle)
npm run asbuild:release  # build/assemblyscript.release.{wasm,js}

cp build/assemblyscript.release.wasm "$dist/asc.wasm"
cp build/assemblyscript.release.js   "$dist/asc.wasm.js"
echo ">> wrote $dist/asc.wasm ($(du -h "$dist/asc.wasm" | cut -f1))"
