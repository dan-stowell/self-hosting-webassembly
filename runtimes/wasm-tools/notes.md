# wasm-tools — the Rust wasm toolbox, compiled to wasm (phase 2)

| | |
|---|---|
| Upstream | bytecodealliance/wasm-tools @ `e6317b4`, Apache-2.0 WITH LLVM-exception |
| Lang | Rust (pure Rust, no native deps) |
| Compiled to wasm by | the Rust toolchain (`cargo build --target wasm32-wasip1`) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

The canonical modern wasm toolbox (`validate`, `print`, `parse`, `dump`,
`smith`, `mutate`, plus the component-model tooling), compiled **to** wasm by
Rust's own `wasm32-wasip1` target and run **inside** the tcc-built toywasm,
operating on wasm. `demo-in-wasm.sh`: `wat2wasm.wasm` (wabt, as wasm) assembles
a module; `wasm-tools.wasm` validates and prints it.

## Why it just works

wasm-tools is pure Rust with no native dependencies, and the project already
supports `wasm32-wasip1` as a build target, so `cargo build --target
wasm32-wasip1 --release --bin wasm-tools` produces a clean
`wasi_snapshot_preview1` module — no patching. (Needs `rustup target add
wasm32-wasip1` once.) ~15 MB; Rust statically links std.

## The path-mapping gotcha (same as wazero)

Rust's wasip1 std resolves a relative path against the WASI preopen whose guest
path is a prefix of it. toywasm's `--wasi-dir .` (guest path `.`) doesn't
prefix-match `hello.wasm`, so opens fail. Map host `.` to guest `/` and pass an
absolute guest path:

    toywasm --wasi --wasi-dir .::/ -- wasm-tools.wasm validate /hello.wasm

## Significance

The third language ecosystem in the floor (after C/C++ and Go): the tcc-built
toywasm now hosts wasm tooling from C (wabt, w2c2, binaryen), Go (wazero), and
Rust (wasm-tools) — all as wasm.
