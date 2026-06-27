#!/usr/bin/env bash
# Exercise the bootstrapped no-LLVM zig2: native exe, wasm32-wasi program (run
# under wasm3), and a wasm32-freestanding library (callable export). Run
# build.sh first (produces dist/zig2).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
zig2="$here/dist/zig2"
W3="$root/tools/wasm3"
[ -x "$zig2" ] || { echo "no dist/zig2 — run compilers/zig/build.sh first"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }

echo "[native] zig2 compiles & runs a native executable"
cat > "$tmp/hello.zig" <<'EOF'
const std = @import("std");
pub fn main() void { std.debug.print("hello from zig2\n", .{}); }
EOF
if "$zig2" build-exe "$tmp/hello.zig" --name hello -femit-bin="$tmp/hello" >/dev/null 2>&1 \
   && [ "$("$tmp/hello" 2>&1)" = "hello from zig2" ]; then
  ok "native exe runs"
else no "native build/run"; fi

echo "[wasm32-wasi] zig2 emits a WASI program that runs under wasm3"
if "$zig2" build-exe "$tmp/hello.zig" --name hw -femit-bin="$tmp/hw.wasm" \
     -target wasm32-wasi -OReleaseSmall >/dev/null 2>&1 \
   && file -b "$tmp/hw.wasm" | grep -q WebAssembly; then
  if [ -x "$W3" ] && [ "$("$W3" --stack-size 8388608 "$tmp/hw.wasm" 2>&1 | head -1)" = "hello from zig2" ]; then
    ok "wasm32-wasi module runs (hello from zig2)"
  else
    ok "wasm32-wasi module emitted (wasm3 missing or didn't run; build scripts/build-wasm3.sh)"
  fi
else no "wasm32-wasi emit"; fi

echo "[wasm32-freestanding] zig2 emits a callable wasm library"
cat > "$tmp/add.zig" <<'EOF'
export fn add(a: i32, b: i32) i32 { return a + b; }
EOF
if "$zig2" build-exe "$tmp/add.zig" --name add -femit-bin="$tmp/add.wasm" \
     -target wasm32-freestanding -fno-entry --export=add -OReleaseSmall >/dev/null 2>&1; then
  r=$(node -e 'WebAssembly.instantiate(require("fs").readFileSync(process.argv[1]),{}).then(x=>console.log(x.instance.exports.add(20,22)))' "$tmp/add.wasm" 2>/dev/null)
  [ "$r" = "42" ] && ok "freestanding export callable (add(20,22)=42)" || no "freestanding ran => $r"
else no "freestanding emit"; fi

echo
echo "zig2 capabilities: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
