# wasm3 — compiled to wasm (roadmap phase 3, wasm-in-wasm)

| | |
|---|---|
| Upstream | wasm3/wasm3 @ `d77cd81` (2026-06-26), MIT |
| Strategy | fast interpreter (tail-call-threaded "M3") |
| Compiled to wasm by | wasi-sdk clang (`--target=wasm32-wasip1`) — 371 KB |

The famous tiny interpreter, compiled **to** wasm and run **inside** the
tcc-built [toywasm](../toywasm/notes.md):

```
native toywasm (tcc)  ▷  wasm3.wasm  ▷  hello_p1.wasm  →  prints
```

`to-wasm.sh` builds it; `demo-in-wasm.sh` runs it (→ a WASI hello printed by
wasm3, executing inside toywasm, executing inside nothing but a tcc binary).

## What it took

- **Clock bit-rot.** wasm3's `m3_api_wasi.c` `convert_clockid` maps wasi clock
  ids to host clock ids as `int`, but wasi-libc's `clockid_t` is an opaque
  pointer and lacks `CLOCK_{PROCESS,THREAD}_CPUTIME_ID`. Patched to return
  `clockid_t`, `#ifdef`-guard the cputime clocks, and use a pointer sentinel
  (to-wasm.sh, idempotent).
- **`clock()` missing.** wasi-libc has no `clock()`; `m3_api_libc.c` references
  it. Stubbed in `wasi_shim.c` (returns 0 — harmless for running modules).
- Built with the **builtin** WASI backend (`d_m3HasWASI`); `m3_api_meta_wasi.c`
  (the host-passthrough backend) is *more* bit-rotted against current wasi-libc
  and was not used.

## Caveat: partial guest WASI

wasm3's builtin WASI host is incomplete — it lacks `fd_filestat_get`, so it
can't run our richer `hello.wasm` (xcc/de-virt output uses it), exactly like
wax. The demo therefore uses a minimal `wasi_snapshot_preview1` guest
([hello_p1.wat](hello_p1.wat)) that only needs `fd_write`. wasm3.wasm itself
runs fine under toywasm; it's the *nested* guest's WASI surface that's limited.
