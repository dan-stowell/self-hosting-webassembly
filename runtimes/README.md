# runtimes — bootstrapping WebAssembly runtimes from nothing

The active thread (see the [repo README](../README.md) for context). Goal: get
from a bare machine to **running wasm with nothing else underneath**, and then to
**rebuilding the runtime inside wasm** — the "Raspberry Pi boots → builds a wasm
runtime from a minimal seed → rebuilds it inside WebAssembly" picture.

- **[survey.md](survey.md)** — the field of wasm runtimes ranked by
  *bootstrappability* (build with a tiny C compiler, run with minimal deps,
  host the compiler that builds it), plus the two bootstrap strategies
  (translate-to-C vs. tiny-C-interpreter) and the next experiments.

## Built entries

- **[w2c2/](w2c2/notes.md)** ✅ — *"no engine at all"* (Path C). `tcc` builds the
  wasm→C translator; we de-virtualize `cc.wasm` (xcc's C→wasm compiler) into a
  native `cc`, compile `hello.c` → `hello.wasm` with it, then de-virtualize and
  run *that* — a full wasm-compiler loop with **zero wasm engine**, tcc + C only.
  Run `runtimes/w2c2/demo.sh`.

## Layout (as entries get built)

```
runtimes/<name>/
  UPSTREAM     # upstream url, pinned commit, license
  build.sh     # build with the minimal toolchain; record what broke
  notes.md     # impl lang, strategy, tiny-C-buildability, runtime deps, WASI
```

Mirrors the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/) thread's
structure. Next targets (from the survey): **toywasm** and **wac/wax** built
with `tcc` (Path B — a persistent interpreter floor).
