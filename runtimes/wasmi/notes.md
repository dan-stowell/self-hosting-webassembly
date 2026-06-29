# wasmi — a Rust wasm interpreter, compiled to wasm (phase 3)

| | |
|---|---|
| Upstream | wasmi-labs/wasmi @ `aaad4aa`, Apache-2.0/MIT |
| Lang | Rust (the `wasmi` core crate; pure Rust) |
| Compiled to wasm by | the Rust toolchain (`cargo build --target wasm32-wasip1`) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

wasmi is a portable Rust wasm interpreter. Compiled **to** wasm and run
**inside** the tcc-built toywasm, it executes a guest module —
interpreter-inside-interpreter. `demo-in-wasm.sh` assembles a guest with
`wat2wasm.wasm` (wabt, as wasm), then runs it with `wasmi-run.wasm`.

## Not the stock CLI — a tiny embedder

wasmi's CLI (`wasmi_cli`) pulls in `cap-std` / `io-extras` for WASI, which use
`#![feature(wasi_ext)]` — a **nightly-only** Rust feature (`error[E0554]` on
stable). Rather than require a nightly toolchain, we pair wasmi's **core crate**
(stable) with a ~30-line embedder (`runner/`): read a module file, instantiate
with an empty `Linker`, call an export with i32 args, print the result.

Feature note: build the core crate with `default-features = false` plus
`["std", "validate"]` — `Module::new` is gated behind the `validate` feature, so
dropping it makes the constructor disappear.

## Why it works as wasm

The wasmi core interpreter is pure Rust with no native dependencies, so
`cargo build --target wasm32-wasip1` produces a clean wasip1 module. Same
preopen path-mapping gotcha as the other Rust/Go targets: map host `.` to guest
`/` (`--wasi-dir .::/`) and pass an absolute guest path.
