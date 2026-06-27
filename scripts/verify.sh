#!/usr/bin/env bash
# Build each "builds-to-wasm" compiler and smoke-test its compiler-as-wasm
# artifact under the local wasm3 runtime. Run scripts/build-wasm3.sh first.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
W3="$root/tools/wasm3"
[ -x "$W3" ] || { echo "runtime missing — run scripts/build-wasm3.sh"; exit 1; }

pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
iswasm(){ file -b "$1" 2>/dev/null | grep -q "WebAssembly"; }

echo "[xcc] C compiler as wasm (end-to-end: compile + run)"
"$root/compilers/xcc/build.sh" >/dev/null 2>&1 || no "xcc build.sh failed"
tmp=$(mktemp -d)
printf '#include <stdio.h>\nint main(void){ printf("xcc-ok\\n"); return 0; }\n' > "$tmp/t.c"
if "$root/compilers/xcc/run-cc.sh" "$tmp/t.c" "$tmp/t.wasm" >/dev/null 2>&1 && iswasm "$tmp/t.wasm"; then
  res=$("$W3" "$tmp/t.wasm" 2>&1 | head -1)
  [[ "$res" == "xcc-ok" ]] && ok "cc.wasm compiled C -> wasm, output runs ($res)" || no "compiled but ran => $res"
else
  no "cc.wasm did not compile t.c to wasm"
fi
rm -rf "$tmp"

echo "[wa] Go-based Wa compiler as wasm"
"$root/compilers/wa/build.sh" >/dev/null 2>&1 || no "wa build.sh failed"
tmp=$(mktemp -d); printf 'func main {\n\tprintln("hi")\n}\n' > "$tmp/hello.wa"
( cd "$tmp" && "$W3" --stack-size 8388608 "$root/compilers/wa/dist/wa.wasm" build -o out.wasm hello.wa ) >/dev/null 2>&1
iswasm "$tmp/out.wasm" && ok "wa.wasm compiled hello.wa -> wasm" || no "wa.wasm did not emit wasm"
rm -rf "$tmp"

echo "[waforth] Forth compiler in wasm"
"$root/compilers/waforth/build.sh" >/dev/null 2>&1 || no "waforth build.sh failed"
iswasm "$root/compilers/waforth/dist/waforth.wasm" && ok "waforth.wasm assembled" || no "waforth.wasm invalid"
if [ -x "$root/compilers/waforth/dist/waforth" ]; then
  res=$(printf ': SQ DUP * ; 7 SQ .\nBYE\n' | "$root/compilers/waforth/dist/waforth" 2>&1 | tr -d '\n ')
  [[ "$res" == *"49"* ]] && ok "REPL ran (compiled & ran a word: 7 SQ . => 49)" || no "REPL => $res"
else
  echo "  SKIP: REPL host not built (run compilers/waforth/build-host.sh)"
fi

echo
echo "verify: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
