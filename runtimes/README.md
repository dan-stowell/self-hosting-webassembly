# runtimes — bootstrapping WebAssembly runtimes from nothing

The active thread (see the [repo README](../README.md) for context). Goal: get
from a bare machine to **running wasm with nothing else underneath**, and then to
**rebuilding the runtime inside wasm** — the "Raspberry Pi boots → builds a wasm
runtime from a minimal seed → rebuilds it inside WebAssembly" picture.

- **[survey.md](survey.md)** — the field of wasm runtimes ranked by
  *bootstrappability* (build with a tiny C compiler, run with minimal deps,
  host the compiler that builds it), plus the two bootstrap strategies
  (translate-to-C vs. tiny-C-interpreter) and the next experiments.
- **[ROADMAP.md](ROADMAP.md)** — compile the wasm world *into* wasm: tiny
  compilers → wasm tools → wasm runtimes, each run under the tcc-built floor.
  First phase-2 win landed: **w2c2 runs as wasm inside toywasm**.

## Built entries

All three built with **tcc** (the tiny compiler), pinned + reproducible:

- **[wac/](wac/notes.md)** ✅ — *Path A, smallest proof*. `tcc` builds `wax`
  (~78 KB pure interpreter); it executes a hand-written WASI module. Needed 3
  tcc-gap fixes (readline guard, `__builtin` bit-op shim, `-rdynamic`). Caveats:
  legacy `wasi_unstable` ABI + 32-bit assumption → stepping-stone, not a floor.
  Run `runtimes/wac/run.sh`.
- **[toywasm/](toywasm/notes.md)** ✅ — *Path B, the persistent floor*. `tcc`
  builds toywasm (665 KB, full modern WASI). It **hosts xcc's `cc.wasm`**:
  compiles `hello.c` → wasm *inside the interpreter*, then runs it. A tiny
  compiler builds an engine that hosts a real compiler. Run `runtimes/toywasm/demo.sh`.
- **[w2c2/](w2c2/notes.md)** ✅ — *Path C, "no engine at all"*. `tcc` builds the
  wasm→C translator; we de-virtualize `cc.wasm` into a native `cc`, compile
  `hello.c` → `hello.wasm` with it, then de-virtualize and run *that* — a full
  wasm-compiler loop with **zero wasm engine**, tcc + C only.
  Run `runtimes/w2c2/demo.sh`.

Together: **Path C** de-virtualizes a *known* wasm into native code (no engine);
**Path B** keeps a tiny tcc-built engine that hosts *arbitrary* current WASI
programs, toolchain included; **Path A** is the minimal interpreter proof.

## The floor, populated: the whole wasm world *as* wasm

Building on Path B, the roadmap compiled the wasm toolchain **and a fleet of
wasm runtimes** to wasm, each run inside the one tcc-built toywasm.
[`showcase.sh`](showcase.sh) runs a single guest through every runtime in the
floor at once:

```
runtime     lang   result
-------------------------------------------
  wasm3       C      OK   Result: 3628800
  wasm-interp C      OK   fac(i32:10) => i32:3628800
  WAMR        C      OK   fac => i32:3628800
  fizzy       C++    OK   fac => i32:3628800
  wazero      Go     OK   hello from wasm3, running inside tcc-built toywasm
  wasmi       Rust   OK   fac => i32:3628800
  wasmtime    Rust   OK   fac => i32:3628800
```

Four language ecosystems (C, C++, Go, Rust), all as wasm, on a ~688 KB
tcc-built host — and `wasmtime` runs its full Cranelift→Pulley pipeline inside
the sandbox. Each `runtimes/<name>/` entry adds a `to-wasm.sh` (compile it **to**
wasm) and `demo-in-wasm.sh` (run it **as** wasm in the floor) alongside the
original `build.sh`. **Tools** as wasm too: [wabt](wabt/) (wat2wasm, wasm2wat,
wasm-interp, wasm2c, …), [binaryen](binaryen/) (wasm-opt/as/dis),
[wasm-tools](wasm-tools/), [w2c2](w2c2/). And the **compilers** come full
circle: [wcpl](wcpl/) is a self-hosted C→wasm compiler that compiles *itself*
to `wcpl.wasm`, then runs as wasm in the floor compiling C to wasm. See
[ROADMAP.md](ROADMAP.md) for the full status table.

## Layout (as entries get built)

```
runtimes/<name>/
  UPSTREAM     # upstream url, pinned commit, license
  build.sh     # build with the minimal toolchain; record what broke
  notes.md     # impl lang, strategy, tiny-C-buildability, runtime deps, WASI
```

Mirrors the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/) thread's
structure. Paths A, B, C are now all built (above); the remaining survey thread
is the from-nothing seed chain (M2-Planet → Mes → tcc), deferred.
