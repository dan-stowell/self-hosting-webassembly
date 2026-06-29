# toywasm — Path B: a tiny compiler builds an interpreter that hosts a compiler

| | |
|---|---|
| Upstream | yamt/toywasm @ `6fc2186` (2026-06-03), MIT |
| Strategy | pure interpreter (no big-switch jump table, no labels-as-values) |
| Built with | **tcc 0.9.27** (cmake/ninja orchestrate; tcc compiles every `.c`) — 665 KB |
| WASI | **full, modern `wasi_snapshot_preview1`** + directory mapping |

## What was proven (Path B — the persistent floor)

`./demo.sh`, all on top of a tcc-built interpreter:

1. **tcc builds toywasm** — all 71 `.c` files (lib + libwasi + cli) compile with
   tcc, threads off (avoids the `_Atomic` path), tests off (avoids cmocka). No
   `_Generic`, no computed gotos, no LLVM — it just builds. Result: a 665 KB
   modern-WASI interpreter.
2. **It runs current WASI** — toywasm executes `wasi_snapshot_preview1` modules,
   including ones `wax` (Path A) flat-out rejects.
3. **It hosts a real compiler** — we run xcc's `cc.wasm` *inside* toywasm (with
   `--wasi-dir` mapping the guest `/usr/include`, `/usr/lib`, `/tmp`), and it
   compiles `input.c` → `out.wasm` (valid wasm). Then toywasm runs that output:
   `compiled by cc.wasm, hosted in tcc-built toywasm`.

So a **tiny C compiler builds an interpreter that hosts a real C→wasm compiler**,
which runs entirely inside the interpreter and produces working wasm. This is the
complement to [w2c2](../w2c2/notes.md)'s "no engine at all": Path C de-virtualizes
a *known* wasm into native code with no engine; Path B keeps a small, tcc-built
engine present and uses it to host and run *arbitrary* current WASI programs —
including the toolchain.

## What it took

- **cmake + ninja**, but only as orchestration — `CMAKE_C_COMPILER=tcc` does all
  the actual compilation. (A pure-bootstrap variant would replace cmake with a
  flat `tcc *.c` plus a hand-written config header; the language-level build is
  already tcc-clean, so that's plumbing, not a blocker.)
- **`-DTOYWASM_ENABLE_WASM_THREADS=OFF`** to avoid `_Atomic` (tcc 0.9.27's weak
  spot); **`-DBUILD_TESTING=OFF -DTOYWASM_BUILD_UNITTEST=OFF`** to avoid the
  cmocka test dependency.
- **`-DTOYWASM_ENABLE_WASM_EXCEPTION_HANDLING=ON`** so the floor can run wasm
  modules that use the standardized exception-handling proposal (`try_table`) —
  needed to host [binaryen](../binaryen/notes.md), which is C++-with-exceptions
  compiled against wasi-sdk's `eh/` multilib.
- Pass `--` before the guest module so toywasm stops parsing options and hands
  `-o /out.wasm /input.c` to the hosted compiler.

## Also: toywasm compiled TO wasm — wasm-in-wasm (roadmap phase 3)

toywasm also compiles *to* wasm (upstream ships `build-wasm32-wasi.sh`).
`to-wasm.sh` builds a 910 KB `toywasm.wasm` with wasi-sdk; `demo-wasm-in-wasm.sh`
then runs it **inside the tcc-built native toywasm**, nested up to three deep,
executing a real program at the bottom:

```
native toywasm (tcc)  ▷  toywasm.wasm  ▷  toywasm.wasm  ▷  hello.wasm  →  prints
```

A wasm runtime, compiled to wasm, running inside a wasm runtime a tiny compiler
built. This is the headline of [ROADMAP.md](../ROADMAP.md) phase 3.

## Why this is the floor wac/wax couldn't be

`wax` is smaller and language-simpler, but it speaks the legacy `wasi_unstable`
ABI, lacks calls like `fd_filestat_get`, and assumes a 32-bit host ABI — so it
can't host a modern toolchain. toywasm is a bit bigger and needs cmake plumbing,
but it is **complete and current**, which is what "a persistent wasm environment
that can rebuild its own tools" actually requires.
