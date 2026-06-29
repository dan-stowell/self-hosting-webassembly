# webcc

A C/C++-like web language → WebAssembly compiler, written in C++ (the backend
for [Coi](https://github.com/io-eric/coi)).

| | |
|---|---|
| Tier / effort | 1 / 3 |
| Impl language | C++20 |
| Backend | own codegen, **but shells out to external `lld`** to link |
| Status | 🅥 vendored — builds native; **blocked** for compiler-as-wasm |
| Artifact | (native `webcc`; wasm build blocked) |

## What works

- Native build: `bash src/build.sh` (needs `clang++` ≥16, `ninja`, and `lld`).
  Produces a 464 KB `webcc` that compiles `.cc` source to wasm.
- An emscripten build of the C++ sources links and produces a ~16 KB
  `webcc.wasm` + JS loader.

## Why compiler-as-wasm is blocked

webcc does its own codegen but **execs `lld`** for the link step. A process
running inside wasm can't `exec` an external linker, so the emscripten build
fails at link time. Making webcc self-host to wasm would require bundling a
wasm linker (lld-as-wasm, or replacing the link step) — the same native-backend
wall that pushes LLVM/Binaryen-based compilers up the effort scale.

This is recorded as a data point; not pursued further for now.

## Our changes

None.
