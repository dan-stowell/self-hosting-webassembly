#!/usr/bin/env bash
# Roadmap phase 3: compile fizzy — a fast C++ wasm interpreter — TO wasm with
# wasi-sdk, and run it inside the tcc-built toywasm. fizzy uses C++ exceptions,
# so this rides the same eh/ multilib recipe as binaryen (see
# ../binaryen/notes.md and memory wasi-sdk-cpp-exceptions-recipe).
#
# fizzy's own CLI (fizzy-wasi) depends on uvwasi/libuv, which won't compile to
# wasm — but libfizzy's core has no external deps. We pair it with a tiny C-API
# embedder (fizzy-run.c) that loads a module and runs an export. Output:
# build.wasm/fizzy-run (a wasm module).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASI_SDK="$repo/tools/wasi-sdk"
SR="$WASI_SDK/share/wasi-sysroot"
EH="$SR/lib/wasm32-wasip1/eh"
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"

[ -x "$WASI_SDK/bin/clang" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
[ -d "$EH" ] || { echo "[fizzy] no eh multilib at $EH"; exit 1; }

if [ ! -d "$src/.git" ]; then
  echo "[fizzy->wasm] cloning @ $ref"
  git clone https://github.com/wasmx/fizzy "$src"
  git -C "$src" checkout --detach "$ref"
fi

# pass-through wasm-opt shim (stale system wasm-opt can't parse new EH opcodes)
shim="$here/.shim"; mkdir -p "$shim"
printf '#!/bin/sh\nin="";out="";prev="";for a in "$@";do [ "$prev" = "-o" ]&&out="$a";case "$a" in -*) ;; *) [ -z "$in" ]&&in="$a";; esac;prev="$a";done;[ -n "$out" ]&&[ "$in" != "$out" ]&&cp "$in" "$out";exit 0\n' > "$shim/wasm-opt"
chmod +x "$shim/wasm-opt"
export PATH="$shim:$PATH"

CXX="$WASI_SDK/bin/clang++"
CC="$WASI_SDK/bin/clang"
TGT="--target=wasm32-wasip1"
EHFLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false"
# libc++ (LLVM 19+) dropped char_traits<uint8_t>, which fizzy's bytes.hpp needs;
# force-include a minimal specialization ahead of <string>.
INC="-include $here/byte_char_traits.hpp -I$src/include -I$src/lib -I$src/lib/fizzy"
out="$src/build.wasm"; rm -rf "$out"; mkdir -p "$out/obj"

echo "[fizzy->wasm] compiling libfizzy (C++ w/ exceptions)"
for f in "$src"/lib/fizzy/*.cpp; do
  o="$out/obj/$(basename "$f" .cpp).o"
  "$CXX" $TGT $EHFLAGS -O2 -std=c++17 $INC -c "$f" -o "$o"
done
echo "[fizzy->wasm] compiling embedder fizzy-run.c"
"$CC" $TGT -O2 -I"$src/include" -c "$here/fizzy-run.c" -o "$out/obj/fizzy-run.o"

echo "[fizzy->wasm] linking fizzy-run"
"$CXX" $TGT -fwasm-exceptions -O2 "$out"/obj/*.o -L"$EH" -lunwind -o "$out/fizzy-run"
echo "[fizzy->wasm] OK: $out/fizzy-run ($(stat -c%s "$out/fizzy-run") bytes, $(file -b "$out/fizzy-run" | grep -o WebAssembly))"
