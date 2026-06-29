#!/usr/bin/env bash
# Roadmap phase 3: compile wasm3 (the famous tiny interpreter) TO wasm with
# wasi-sdk, so it can run inside another wasm runtime (wasm-in-wasm).
# Output: src/wasm3.wasm (~371 KB).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
WASICC="$repo/tools/wasi-sdk/bin/clang"
ref=$(awk -F': *' '/^commit:/{print $2}' "$here/UPSTREAM")
src="$here/src"

[ -x "$WASICC" ] || "$repo/runtimes/scripts/setup-wasi-sdk.sh"
if [ ! -d "$src/.git" ]; then
  echo "[wasm3->wasm] cloning @ $ref"
  git clone https://github.com/wasm3/wasm3 "$src"; git -C "$src" checkout --detach "$ref"
fi

w="$src/source/m3_api_wasi.c"
# Patch 1: the POSIX convert_clockid maps wasi clock ids to host clockids as int,
# but wasi-libc's clockid_t is a pointer and lacks the cputime ids. Return
# clockid_t and #ifdef-guard the cputime clocks. Idempotent.
perl -0pi -e 's/static inline\nint convert_clockid\(__wasi_clockid_t in\) \{\n    switch \(in\) \{\n    case __WASI_CLOCKID_MONOTONIC:            return CLOCK_MONOTONIC;\n    case __WASI_CLOCKID_PROCESS_CPUTIME_ID:   return CLOCK_PROCESS_CPUTIME_ID;\n    case __WASI_CLOCKID_REALTIME:             return CLOCK_REALTIME;\n    case __WASI_CLOCKID_THREAD_CPUTIME_ID:    return CLOCK_THREAD_CPUTIME_ID;\n    default: return -1;\n    \}\n\}/static inline\nclockid_t convert_clockid(__wasi_clockid_t in) {\n    switch (in) {\n    case __WASI_CLOCKID_MONOTONIC:            return CLOCK_MONOTONIC;\n    case __WASI_CLOCKID_REALTIME:             return CLOCK_REALTIME;\n#ifdef CLOCK_PROCESS_CPUTIME_ID\n    case __WASI_CLOCKID_PROCESS_CPUTIME_ID:   return CLOCK_PROCESS_CPUTIME_ID;\n#endif\n#ifdef CLOCK_THREAD_CPUTIME_ID\n    case __WASI_CLOCKID_THREAD_CPUTIME_ID:    return CLOCK_THREAD_CPUTIME_ID;\n#endif\n    default: return (clockid_t)-1;\n    }\n}/s' "$w"
# Patch 2: the two call sites (int clk + clk<0 check) -> clockid_t + sentinel. Idempotent.
perl -0pi -e 's/int clk = convert_clockid\(wasi_clk_id\);\n    if \(clk < 0\)/clockid_t clk = convert_clockid(wasi_clk_id);\n    if (clk == (clockid_t)-1)/g' "$w"

echo "[wasm3->wasm] compiling with wasi-sdk clang (wasm32-wasip1, builtin WASI)"
srcs=$(ls "$src"/source/*.c | grep -vE 'uvwasi|tracer|meta_wasi')
"$WASICC" --target=wasm32-wasip1 -O2 -I"$src/source" -Dd_m3HasWASI=1 \
  $srcs "$src/platforms/app/main.c" "$here/wasi_shim.c" -o "$src/wasm3.wasm"
echo "[wasm3->wasm] OK: $src/wasm3.wasm ($(stat -c%s "$src/wasm3.wasm") bytes)"
