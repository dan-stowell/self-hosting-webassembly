# Roadmap: compile the wasm world *into* wasm

The runtimes thread proved you can build a wasm floor with tiny tools (Paths
A/B/C). The next program is to **populate that floor** — compile the things that
make and run wasm *to* wasm — in three escalating phases.

Every target, once compiled to wasm, is validated two ways with what we already
built:
- **run it** under the tcc-built [toywasm](toywasm/notes.md) (Path B), and/or
- **de-virtualize it** to native via [w2c2](w2c2/notes.md) + tcc (Path C).

## Done so far

| phase | target | as wasm | validated |
|---|---|---|---|
| 1 | xcc `cc.wasm` (tiny C→wasm compiler) | self-hosted | hosted in toywasm to compile+run C ([toywasm/demo.sh](toywasm/demo.sh)) |
| 2 | **w2c2** (wasm→C translator) | wasi-sdk | runs in toywasm ([w2c2/demo-in-wasm.sh](w2c2/demo-in-wasm.sh)) |
| 2 | **wabt** ×6 (wat2wasm, wasm2wat, objdump, validate, strip, desugar) | wasi-sdk | run in toywasm; also de-virtualized to native (Path C) ([wabt/demo-in-wasm.sh](wabt/demo-in-wasm.sh)) |
| 3 | **toywasm** (our floor) | wasi-sdk | runs inside tcc-built toywasm, 3 deep ([toywasm/demo-wasm-in-wasm.sh](toywasm/demo-wasm-in-wasm.sh)) |
| 3 | **wasm3** (famous tiny interp) | wasi-sdk | runs inside toywasm ([wasm3/demo-in-wasm.sh](wasm3/demo-in-wasm.sh)) |

Blocked / deferred: **binaryen** (C++ exceptions vs no-exceptions libc++),
**wac/wax** (dlsym import model absent in wasm), **WAMR** (wasi self-host port).

## The enabler: a C/C++ → wasm compiler

The targets are tiny; the bridge is a real compiler-to-wasm. We use **wasi-sdk**
(clang + `wasm-ld` + wasi-libc) for clean `wasi_snapshot_preview1` output that
runs under toywasm. Note the loop-closer: clang *itself* compiles to wasm (w2c2
ships an `llvm.wasm` example), so even the bridge can eventually live in the
floor. `emcc` is also present for the C++ targets that need it.

## Phase 1 — tiny compilers that emit wasm → compiled to wasm ✅

The exemplars already exist as wasm in the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/) thread, because
they self-host: **xcc/`cc.wasm`**, **WAForth**, **AssemblyScript**, **Schism**,
**wa**, **Zig** (`zig1.wasm`). Demonstrated under the floor lens:
`toywasm/demo.sh` hosts xcc's `cc.wasm` (a tiny C→wasm compiler, *as wasm*)
inside the tcc-built toywasm, compiles `hello.c` → wasm, and runs it — a tiny
compiler emitting wasm, running as wasm, in a tiny-compiler-built runtime.

## Phase 2 — tools that operate on / emit wasm → compiled to wasm

The wasm toolbox, itself as wasm:
- **w2c2** (wasm→C translator) ✅ **done** — compiled to wasm with wasi-sdk
  (`runtimes/w2c2/to-wasm.sh`), runs under the tcc-built toywasm and translates
  a `.wasm` to C inside the sandbox (`runtimes/w2c2/demo-in-wasm.sh`). The tool
  that de-virtualizes wasm, now running *as* wasm.
- **wabt** ✅ **done** — `wat2wasm`, `wasm2wat`, `wasm-objdump`, `wasm-validate`,
  `wasm-strip`, `wat-desugar` all compiled to wasm (`runtimes/wabt/to-wasm.sh`)
  and run under the tcc-built toywasm, round-tripping a module
  (`runtimes/wabt/demo-in-wasm.sh`). C++, but exception-free so wasi-sdk's
  no-exceptions libc++ is fine.
- **binaryen**: `wasm-opt`, `wasm-as`, `wasm-dis` (C++) — **blocked**: binaryen
  uses C++ exceptions, and wasi-sdk 33's libc++ has no exception runtime
  (`__cxa_throw` undefined; `-fwasm-exceptions` needs unsupported sysroot bits).
  Would need an exception-enabled libc++ or an `-fno-exceptions` port.
- (stretch) `wasm-tools` (Rust).

## Phase 3 — wasm runtimes → compiled to wasm (wasm-in-wasm)

Run a wasm runtime *inside* a wasm runtime:
- **toywasm** (C11) ✅ **done** — our own floor compiled to wasm
  (`runtimes/toywasm/to-wasm.sh`); `toywasm.wasm` runs **inside the tcc-built
  native toywasm**, nested 3 deep, executing a real program at the bottom
  (`runtimes/toywasm/demo-wasm-in-wasm.sh`). The headline wasm-in-wasm.
- **wasm3** (C) ✅ **done** — the famous tiny interpreter compiled to wasm
  (`runtimes/wasm3/to-wasm.sh`, after patching its bit-rotted WASI clock mapping
  + a `clock()` shim) and run inside the tcc-built toywasm
  (`runtimes/wasm3/demo-in-wasm.sh`). Caveat: wasm3's builtin guest-WASI lacks
  `fd_filestat_get`, so nested guests must stay minimal.
- **WAMR** classic interp (C), **wac/wax** (C; note its `dlsym` import model
  doesn't exist in wasm — would need rework).

The end state: a tcc-built toywasm that can run the compilers, the wasm tools,
*and* other wasm runtimes — all as wasm — i.e. the floor can rebuild and re-run
its entire world without leaving WebAssembly.
