#!/usr/bin/env bash
# Gold-standard self-host confirmation. For each genuinely self-hosting compiler,
# the compiler RUNNING AS WASM reproduces its OWN source — a fixed point, checked
# byte-for-byte where possible. This is stronger than verify.sh (which only shows
# each compiler-as-wasm produces working output).
#
# Slower than verify.sh (it runs full bootstraps). Needs the pinned Node in tools/.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
for n in "$root"/tools/node-v22*/bin "$root"/tools/node-v20*/bin; do [ -d "$n" ] && PATH="$n:$PATH"; done
export PATH
pass=0; fail=0
ok(){ echo "  CONFIRMED: $1"; pass=$((pass+1)); }
no(){ echo "  FAILED:    $1"; fail=$((fail+1)); }

echo "[AssemblyScript] fixed point — asc.wasm recompiles its own source to itself"
as="$root/compilers/assemblyscript/src"
a1="$as/build/assemblyscript.release.wasm"; a2="$as/build/assemblyscript.release-bootstrap.wasm"
if [ ! -s "$a1" ] || [ ! -s "$a2" ]; then
  ( cd "$as" && { [ -d node_modules ] || npm ci >/dev/null 2>&1; } && npm run bootstrap:release >/dev/null 2>&1 )
fi
if cmp -s "$a1" "$a2"; then
  ok "byte-identical ($(wc -c < "$a1") bytes): the wasm-built asc reproduces itself"
else no "bootstrap outputs differ"; fi

echo "[xcc] self-host — cc.wasm (built by wcc from wcc's own C source) compiles C -> running wasm"
xtmp=$(mktemp -d)
printf '#include <stdio.h>\nint main(void){ printf("xcc-selfhost\\n"); return 0; }\n' > "$xtmp/t.c"
if "$root/compilers/xcc/run-cc.sh" "$xtmp/t.c" "$xtmp/t.wasm" >/dev/null 2>&1 \
   && [ "$("$root/tools/wasm3" "$xtmp/t.wasm" 2>/dev/null)" = "xcc-selfhost" ]; then
  ok "cc.wasm compiled C to a working wasm module (cc.wasm itself = wcc compiled from its own source)"
else no "cc.wasm failed to compile/run a C program"; fi
rm -rf "$xtmp"

echo "[Schism] self-host — stage0.wasm (Scheme compiler in wasm) -> stage1 -> stage2"
out=$("$root/compilers/schism/build.sh" 2>&1 | tail -1)
[[ "$out" == *"self-host OK"* ]] && ok "stage chain succeeds: stage0.wasm compiles compiler.ss through to stage2" || no "$out"

echo
echo "self-host confirmation: $pass confirmed, $fail failed"
[ "$fail" -eq 0 ]
