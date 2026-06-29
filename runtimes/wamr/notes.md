# WAMR — wasm-micro-runtime classic interpreter, compiled to wasm (phase 3)

| | |
|---|---|
| Upstream | bytecodealliance/wasm-micro-runtime @ `e571797`, Apache-2.0 WITH LLVM-exception |
| Lang | C |
| Compiled to wasm by | wasi-sdk clang (`wasi-sdk-p1.cmake`) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

The named deferred runtime, now done. WAMR's classic interpreter compiled **to**
wasm and run **inside** the tcc-built toywasm, executing a guest module
(interpreter-inside-interpreter), `fac(10)=3628800`. `demo-in-wasm.sh` assembles
a guest with `wat2wasm.wasm` (wabt, as wasm), then runs it with `iwasm-run.wasm`.

## Why it was "deferred", and the three moves that unblocked it

WAMR assumes a native OS: per-arch assembly for native calls, a POSIX platform
layer (mmap/pthread/signals/sockets), and hardware-trap bounds checks. None of
that exists inside wasm. Three settings make it self-host:

1. **`WAMR_BUILD_INVOKE_NATIVE_GENERAL=1`** — WAMR ships a portable C
   implementation of `invokeNative` (the native-call ABI marshaller). Selecting
   it avoids every `invokeNative_*.s` arch assembly file, which is the usual
   wall for non-native targets.
2. **A minimal custom WASI platform** (`wasi-platform/`, ~120 lines of C) that
   implements just the vmcore `os_*` API atop wasi-libc: a **malloc-backed
   `os_mmap`** (over-aligned to 64 KiB, base pointer stashed for `os_munmap`),
   no-op `os_mprotect`/cache flushes, and single-threaded mutex stubs. No
   pthread/signal/socket/real-mmap needed. `to-wasm.sh` drops this in as a new
   `core/shared/platform/wasi` so WAMR's own cmake picks it up.
3. **`WAMR_DISABLE_HW_BOUND_CHECK=1`** — software bounds checks, since wasm has
   no signals/`SIGSEGV` guard pages. `os_thread_get_stack_boundary()` returns
   NULL so WAMR skips native-stack-overflow detection too.

Build config: classic interpreter (`WAMR_BUILD_FAST_INTERP=0`), `LIBC_BUILTIN`
(no WASI passthrough), AOT/JIT/threads/sockets/SIMD off. `WAMR_BUILD_TARGET` is
set to `X86_32` only to match wasm32's 32-bit pointers; the arch asm it would
otherwise select is bypassed by move #1.

## Embedder, not the stock CLI

WAMR's `iwasm` CLI (`product-mini/platforms/posix/main.c`) carries WASI/signal
assumptions, so we pair the runtime lib with a ~60-line embedder
(`iwasm-run.c`) using `wasm_export.h`: load → instantiate → lookup → call an
export with i32 args.
