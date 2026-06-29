# Roadmap: compile the wasm world *into* wasm

The runtimes thread proved you can build a wasm floor with tiny tools (Paths
A/B/C). The next program is to **populate that floor** — compile the things that
make and run wasm *to* wasm — in three escalating phases.

Every target, once compiled to wasm, is validated two ways with what we already
built:
- **run it** under the tcc-built [toywasm](toywasm/notes.md) (Path B), and/or
- **de-virtualize it** to native via [w2c2](w2c2/notes.md) + tcc (Path C).

## The enabler: a C/C++ → wasm compiler

The targets are tiny; the bridge is a real compiler-to-wasm. We use **wasi-sdk**
(clang + `wasm-ld` + wasi-libc) for clean `wasi_snapshot_preview1` output that
runs under toywasm. Note the loop-closer: clang *itself* compiles to wasm (w2c2
ships an `llvm.wasm` example), so even the bridge can eventually live in the
floor. `emcc` is also present for the C++ targets that need it.

## Phase 1 — tiny compilers that emit wasm → compiled to wasm

The exemplars already exist as wasm in the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/) thread, because
they self-host: **xcc/`cc.wasm`**, **WAForth**, **AssemblyScript**, **Schism**,
**wa**, **Zig** (`zig1.wasm`). This phase consolidates them under the floor lens
(run each under toywasm; de-virtualize each) and adds any tiny wasm-emitting
compiler buildable straight through wasi-sdk (e.g. a second, clang-built
`wcc.wasm`).

## Phase 2 — tools that operate on / emit wasm → compiled to wasm

The wasm toolbox, itself as wasm:
- **w2c2** (wasm→C translator) ✅ **done** — compiled to wasm with wasi-sdk
  (`runtimes/w2c2/to-wasm.sh`), runs under the tcc-built toywasm and translates
  a `.wasm` to C inside the sandbox (`runtimes/w2c2/demo-in-wasm.sh`). The tool
  that de-virtualizes wasm, now running *as* wasm.
- **wabt**: `wat2wasm`, `wasm2wat`, `wasm-objdump`, `wasm-validate`, `wasm-strip` (C++).
- **binaryen**: `wasm-opt`, `wasm-as`, `wasm-dis` (C++).
- (stretch) `wasm-tools` (Rust).

## Phase 3 — wasm runtimes → compiled to wasm (wasm-in-wasm)

Run a wasm runtime *inside* a wasm runtime:
- **toywasm** (C11) ✅ **done** — our own floor compiled to wasm
  (`runtimes/toywasm/to-wasm.sh`); `toywasm.wasm` runs **inside the tcc-built
  native toywasm**, nested 3 deep, executing a real program at the bottom
  (`runtimes/toywasm/demo-wasm-in-wasm.sh`). The headline wasm-in-wasm.
- **wasm3** (C) — classic small interpreter; *attempted*: both its WASI backends
  (`m3_api_wasi.c`, `m3_api_meta_wasi.c`) have bit-rotted against wasi-sdk 33's
  wasi-libc (drifted signatures, clock types) — needs a WASI-backend patch.
- **WAMR** classic interp (C), **wac/wax** (C; note its `dlsym` import model
  doesn't exist in wasm — would need rework).

The end state: a tcc-built toywasm that can run the compilers, the wasm tools,
*and* other wasm runtimes — all as wasm — i.e. the floor can rebuild and re-run
its entire world without leaving WebAssembly.
