#!/usr/bin/env bash
# Roadmap phase 2: compile binaryen (wasm-opt, wasm-as, wasm-dis) TO wasm with
# wasi-sdk. Binaryen uses C++ exceptions, which earlier blocked us — wasi-sdk's
# DEFAULT libc++ has no exception runtime. The unlock: wasi-sdk 33 ships an
# exception-enabled multilib under lib/<target>/eh/ (libc++/libc++abi/libunwind
# built for wasm EH). We compile with -fwasm-exceptions and the NEW try_table
# encoding (-wasm-use-legacy-eh=false) so the result runs under the tcc-built
# toywasm (which implements the standardized exception-handling proposal).
#
# One catch: wasi-sdk's clang driver runs a post-link `wasm-opt -O3`, and any
# stale system wasm-opt can't parse the new EH opcodes — circular, since
# wasm-opt is exactly what we're building. We shim it to a pass-through so the
# build needs no pre-existing wasm-opt at all.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASI_SDK="$repo/tools/wasi-sdk"
SR="$WASI_SDK/share/wasi-sysroot"
EH="$SR/lib/wasm32-wasip1/eh"            # exception-enabled libc++/libc++abi/libunwind
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"
TOOLS=${TOOLS:-"wasm-opt wasm-as wasm-dis"}

[ -x "$WASI_SDK/bin/clang" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
[ -d "$EH" ] || { echo "[binaryen] no eh multilib at $EH — wrong wasi-sdk?"; exit 1; }
for t in cmake ninja; do command -v $t >/dev/null || { echo "[binaryen] need $t"; exit 1; }; done

if [ ! -d "$src/.git" ]; then
  echo "[binaryen->wasm] cloning @ $ref"
  git clone --depth 1 https://github.com/WebAssembly/binaryen "$src"
  git -C "$src" fetch --depth 1 origin "$ref" && git -C "$src" checkout --detach "$ref" || true
fi

# Pass-through wasm-opt shim: clang driver calls `wasm-opt IN -O3 -o OUT`; we
# just copy IN->OUT. No pre-existing wasm-opt is required to build wasm-opt.
shim="$here/.shim"; mkdir -p "$shim"
cat > "$shim/wasm-opt" <<'EOF'
#!/bin/sh
in=""; out=""; prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  case "$a" in -*) ;; *) [ -z "$in" ] && in="$a";; esac
  prev="$a"
done
[ -n "$out" ] && [ "$in" != "$out" ] && cp "$in" "$out"
exit 0
EOF
chmod +x "$shim/wasm-opt"
export PATH="$shim:$PATH"

# EH recipe: new try_table encoding + the eh/ multilib + libunwind.
EHFLAGS="-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false"
LDEH="-fwasm-exceptions -L$EH -lunwind"

echo "[binaryen->wasm] configuring with wasi-sdk + EH multilib"
rm -rf "$src/build.wasm"
cmake -S "$src" -B "$src/build.wasm" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK/share/cmake/wasi-sdk-p1.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="$EHFLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$LDEH" \
  -DBUILD_TESTS=OFF -DBUILD_SHARED_LIBS=OFF -DINSTALL_LIBS=OFF \
  -DBYN_ENABLE_LTO=OFF -DENABLE_WERROR=OFF >/dev/null

echo "[binaryen->wasm] building: $TOOLS (this takes a while)"
for t in $TOOLS; do
  cmake --build "$src/build.wasm" --target "$t" >/dev/null 2>&1 || echo "  WARN: $t failed"
done
echo "[binaryen->wasm] OK:"
for t in $TOOLS; do
  f="$src/build.wasm/bin/$t"; [ -f "$f" ] || f="$src/build.wasm/$t"
  [ -f "$f" ] && echo "  $t ($(stat -c%s "$f") bytes, $(file -b "$f" | grep -o WebAssembly))"
done
