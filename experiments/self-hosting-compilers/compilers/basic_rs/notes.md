# basic_rs

A BASIC (Dartmouth) interpreter/compiler in Rust; its `basic2wasm` crate
compiles BASIC → WebAssembly. From 2019.

| | |
|---|---|
| Tier / effort | 1 / 3 |
| Impl language | Rust |
| Backend | Binaryen (via the `binaryen` crate, FFI to native C++) |
| Status | 🅥 vendored — **blocked** for compiler-as-wasm |
| Artifact | (blocked) |

## Why compiler-as-wasm is blocked

Rust → `wasm32-wasip1` is normally a clean route, but `basic2wasm` pulls in:
- `binaryen = "0.5.0"` — FFI to the native C++ Binaryen library (built via
  `cc`/`cmake`), which doesn't cross-compile to wasm32.
- `cpuprofiler` — FFI to gperftools, likewise native-only.

So the wasm-emitting crate can't itself be compiled to wasm without first
getting Binaryen-as-wasm. The non-emitting `basic_rs` interpreter crate builds
fine to wasm32, but it isn't the wasm emitter.

A clean Rust self-host-to-wasm needs a compiler that emits wasm via a
**pure-Rust** encoder (`wasm-encoder`/`walrus`) rather than the Binaryen FFI.
Recorded as a data point.

## Our changes

None.
