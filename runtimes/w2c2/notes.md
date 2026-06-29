# w2c2 — "no engine at all"

The first built entry in the runtimes thread, and the realization of **Path C**
from the [survey](../survey.md): you don't need a WebAssembly *engine* to run
WebAssembly. `w2c2` translates a `.wasm` module to portable C; a tiny C compiler
builds it; the result is ordinary native machine code. The runtime evaporates.

| | |
|---|---|
| Upstream | turbolent/w2c2 @ `2a31254` (2025-09-30), MIT |
| Strategy | wasm → C translator (AOT to portable C89) |
| Built with | **tcc 0.9.27** — no LLVM, no cmake, no C++ |
| WASI | yes (w2c2 ships its own host; has upstream-run clang + RustPython) |

## What was proven here (all with `tcc` + C, zero wasm engine)

`./demo.sh`, end to end:

1. **tcc builds the translator** — `w2c2` itself, a 170 KB native binary, built
   by tcc (threads feature dropped; everything else is plain libc).
2. **de-virtualize `cc.wasm` → native `cc`** — xcc's C→wasm compiler (archived
   in [self-hosting-compilers](../../experiments/self-hosting-compilers/compilers/xcc/notes.md),
   342 KB of wasm) becomes 1.67 MB of generated C → a 1.79 MB native executable.
   It is the *same compiler*, now machine code instead of a wasm module.
3. **native `cc` compiles `hello.c` → `hello.wasm`** — a wasm compiler, running
   with no engine, emitting a valid 9,429-byte wasm module.
4. **de-virtualize `hello.wasm` → native, and run it** → prints
   `hello from a de-virtualized wasm C compiler`.

A wasm C-compiler running as native code with no engine, compiling C to wasm —
and that wasm then running as native code with no engine. The loop closes and
nowhere in it is there a WebAssembly runtime.

## The pieces

- **`build.sh`** — clone w2c2 at the pin, build the translator + WASI runtime
  lib with `tcc` (override with `CC=gcc` for fast output).
- **`devirt.sh <module.wasm> <out>`** — the reusable de-virtualizer: turn *any*
  WASI command module into a native binary. Translates, auto-detects the module
  symbol prefix from the generated header, generates a generic WASI harness
  (preopen `/`, call `_start`), and builds it with the tiny compiler.
- **`demo.sh`** — the headline loop above, with assertions.

## Why it matters

This is the cleanest form of "run wasm with nothing else": the *nothing else* is
literally a C compiler. It's also the bootstrap-floor move — it's exactly how
**Zig** bootstraps (its own `wasm2c` on `zig1.wasm`), which we proved in the
compilers thread; `w2c2` generalizes the trick to *any* wasm. Any compiler that
targets wasm can now be folded into a tiny-seed (tcc/Mes/M2-Planet) bootstrap
**without dragging its native toolchain along** — you go through wasm and C.

## Also: w2c2 compiled TO wasm (roadmap phase 2)

w2c2 doesn't only *produce* the floor — it can *live* in it. `to-wasm.sh`
compiles w2c2 to wasm with wasi-sdk clang (one tiny patch: wasi-libc has no
`glob`, so the unused datasegment-cleanup `#error` path is neutralized), giving a
363 KB `w2c2.wasm`. `demo-in-wasm.sh` then runs that **under the tcc-built
toywasm** and has it translate `fac.wasm` → C *inside the sandbox*:

```
toywasm (built by tcc)  ◁─runs─  w2c2.wasm (built by wasi-sdk)  ──emits──▶  fac.c
```

A wasm tool, operating on wasm, running as wasm, in a runtime a tiny compiler
built. This is the first entry of [ROADMAP.md](../ROADMAP.md) phase 2.

## Caveats (honest scope)

- **AOT, not a host.** One module → one native binary. This can't load arbitrary
  *untrusted* wasm at runtime — that genuinely needs an engine (toywasm / WAMR,
  the survey's Path B). This is "I have a known wasm artifact I want to run and
  build from."
- **Filesystem.** w2c2's `resolvePath` uses absolute guest paths as *literal
  host paths*, and the harness preopens `/` → host `/`, so a de-virtualized
  program sees the real filesystem. For the `cc` demo we therefore point xcc at
  its *own* wasm-libc with `-nostdinc -isystem … -L …` (absolute paths that pass
  through) instead of letting it read the host's glibc headers. A real sandbox
  would rebase all paths under a root dir.
- **No threads / tcc output.** We build without the threads feature (tcc); a
  thread-using module needs the threads feature and a threads-capable compiler.
  tcc's output is correct but unoptimized — build with `CC=gcc` for near-native.
- **WASI command modules only.** `devirt.sh` assumes a `_start` entry; a
  pure-compute module that just exports functions (like the `fac` example) needs
  a different harness that calls the export directly.
