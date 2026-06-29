# runtimes — bootstrapping WebAssembly runtimes from nothing

The active thread (see the [repo README](../README.md) for context). Goal: get
from a bare machine to **running wasm with nothing else underneath**, and then to
**rebuilding the runtime inside wasm** — the "Raspberry Pi boots → builds a wasm
runtime from a minimal seed → rebuilds it inside WebAssembly" picture.

- **[survey.md](survey.md)** — the field of wasm runtimes ranked by
  *bootstrappability* (build with a tiny C compiler, run with minimal deps,
  host the compiler that builds it), plus the two bootstrap strategies
  (translate-to-C vs. tiny-C-interpreter) and the next experiments.

## Layout (as entries get built)

```
runtimes/<name>/
  UPSTREAM     # upstream url, pinned commit, license
  build.sh     # build with the minimal toolchain; record what broke
  notes.md     # impl lang, strategy, tiny-C-buildability, runtime deps, WASI
```

Mirrors the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/) thread's
structure. First targets (from the survey): **wac/wax** and **toywasm** built
with `tcc`, and a **w2c2** wasm→C→tcc round-trip.
