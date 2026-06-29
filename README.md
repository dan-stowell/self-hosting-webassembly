# self-hosting-webassembly

Experiments in **self-hosting and bootstrapping WebAssembly** — from "a compiler
that compiles itself to wasm" up to "what would it take to get from *nothing* to
a machine running wasm that can rebuild its own runtime."

## Threads

### 1. `experiments/self-hosting-compilers/` — wasm-emitting compilers, self-hosted *(archived)*

A suite of compilers that emit WebAssembly, vendored and modified so each
compiler *itself* runs as a wasm module — by self-hosting (it already targets
wasm, so it compiles its own source) or by building it with another
wasm-emitting toolchain. Proven self-hosters include **AssemblyScript**
(byte-identical fixed point) and **Zig** (`zig1.wasm` → no-LLVM `zig2` that
emits wasm), plus end-to-end **xcc**, **wa**, **WAForth**, and **Schism**.

See [experiments/self-hosting-compilers/README.md](experiments/self-hosting-compilers/README.md).

### 2. Bootstrapping wasm runtimes from nothing *(active)*

The new direction: take the bootstrap-floor lens — minimal seed → tiny C
compiler (tcc / cproc / M2-Planet → Mes) → real toolchain — and point it at
**WebAssembly runtimes**. For every wasm runtime, what would it take to:

1. **build it with a minimal compiler** (ideally a tiny, itself-bootstrappable
   C compiler — not LLVM/cmake/Rust), and
2. **run it with nothing else** (minimal libc / syscalls / OS), so that
3. once running, it can **execute the compiler(s) that build it** — closing the
   loop *inside* wasm.

The motivating picture: a bare Raspberry Pi that boots, builds a wasm runtime
from a minimal seed, and then rebuilds that runtime *inside* WebAssembly.

Related work (separate project): the bootstrap/tiny-compiler research in
[altdansalt/tiny-languages](https://github.com/altdansalt/tiny-languages) —
small compilers/interpreters verified to run in a wasm runtime or on a barebones
Raspberry Pi, with `bootstrap/` probes (Stage0-POSIX → M2-Planet, GNU Mes,
scratch containers). `wasm3` already appears there.
