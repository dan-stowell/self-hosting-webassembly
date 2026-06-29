# binaryen — wasm-opt/wasm-as/wasm-dis, compiled to wasm *with exceptions* (phase 2)

| | |
|---|---|
| Upstream | WebAssembly/binaryen @ `4514ec8`, Apache-2.0 |
| Lang | C++17, **uses C++ exceptions** (the thing that blocked us before) |
| Compiled to wasm by | wasi-sdk clang++ + its `eh/` exception multilib |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md), built with EH enabled |

The headline "blocked" target from the roadmap, now unblocked. `wasm-opt`,
`wasm-as`, `wasm-dis` compiled **to** wasm and run **inside** the tcc-built
toywasm, operating on wasm:

| tool (as wasm) | size | does |
|---|---|---|
| `wasm-opt` | 24 MB | optimize / transform a module (full `-O3` pass pipeline) |
| `wasm-as`  | 22 MB | assemble `.wat` → `.wasm` |
| `wasm-dis` | 22 MB | disassemble `.wasm` → `.wat` |

`demo-in-wasm.sh` runs all three in the sandbox: `wasm-as.wasm` assembles a
module, `wasm-opt.wasm -O3` optimizes it, `wasm-dis.wasm` disassembles it back,
and toywasm runs the optimized result.

## Why this was blocked, and the unlock

Binaryen's error handling uses real C++ `throw`/`try`/`catch` (45+ source files),
and binaryen's CMake won't build `-fno-exceptions`. wasi-sdk's **default** libc++
is built without an exception runtime (`__cxa_throw` undefined). So the obvious
build fails, and so does `-fwasm-exceptions` against the default sysroot
(`__cpp_exception`, `__wasm_lpad_context`, `_Unwind_CallPersonality` undefined).

Two facts, both initially missed, make it work:

1. **wasi-sdk 33 ships an exception-enabled multilib** at
   `share/wasi-sysroot/lib/wasm32-wasip1/eh/` — `libc++.a`, `libc++abi.a`,
   `libunwind.a` all built for wasm EH. There's no `multilib.yaml`, so clang
   won't auto-select it; we point the linker at it explicitly:
   `-L .../wasm32-wasip1/eh -lunwind` (the `-L` first, so the driver's `-lc++`
   / `-lc++abi` resolve to the eh versions).
2. **toywasm implements the standardized exception-handling proposal**
   (`try_table`, `TOYWASM_ENABLE_WASM_EXCEPTION_HANDLING`). But LLVM defaults to
   the **legacy** `try`/`catch` encoding (opcode `0x06`), which toywasm does not
   implement. We force the new encoding with
   `-mllvm -wasm-use-legacy-eh=false` → toywasm runs it. (We enabled
   `TOYWASM_ENABLE_WASM_EXCEPTION_HANDLING=ON` in `runtimes/toywasm/build.sh`.)

## The circular catch: a stale wasm-opt blocks building wasm-opt

wasi-sdk's clang driver runs a post-link `wasm-opt -O3` on the output. The
`wasm-opt` it finds in `$PATH` here was an old system build (v108) that can't
parse the new EH opcodes — so the link "failed" with a binaryen parse error
while *building binaryen*. `to-wasm.sh` drops a **pass-through `wasm-opt` shim**
ahead on `$PATH` (copies input → `-o` output), so the build needs no
pre-existing wasm-opt at all. Fitting: we don't depend on wasm-opt to build
wasm-opt.

## What it took (`to-wasm.sh`)

- wasi-sdk-p1 toolchain file, `BUILD_SHARED_LIBS=OFF` (wasm has no .so),
  `BUILD_TESTS=OFF`, `INSTALL_LIBS=OFF`, `BYN_ENABLE_LTO=OFF`, `ENABLE_WERROR=OFF`.
- `CMAKE_CXX_FLAGS = -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false`
- `CMAKE_EXE_LINKER_FLAGS = -fwasm-exceptions -L<eh> -lunwind`
- the pass-through `wasm-opt` shim on `$PATH`.
- Threads: binaryen uses `std::thread`, which *links* on wasm32-wasip1;
  `hardware_concurrency()` returns 0 → `getNumCores()` returns 1 → it never
  actually spawns a thread. No patching needed.

## Validation

Path B only. Path C (w2c2 de-virtualization) is impractical here: 24 MB of wasm
and w2c2 doesn't translate the EH opcodes. Running under the EH-enabled tcc-built
toywasm (Path B) is the proof — and it exercises C++ exceptions on every run
(binaryen throws and catches during parse/validate).
