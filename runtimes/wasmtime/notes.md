# wasmtime — the reference runtime (Pulley), compiled to wasm (phase 3)

| | |
|---|---|
| Upstream | bytecodealliance/wasmtime @ `08c456e`, Apache-2.0 WITH LLVM-exception |
| Lang | Rust |
| Compiled to wasm by | the Rust toolchain (`cargo build --target wasm32-wasip1`) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

The marquee: the Bytecode Alliance **reference runtime**, compiled **to** wasm
and run **inside** the tcc-built toywasm — and not just the interpreter. When
`wasmtime-run.wasm` loads a guest it runs its **full Cranelift pipeline**, but
lowered to **Pulley bytecode** instead of native machine code, then interprets
that bytecode with **Pulley**. So a wasm-to-bytecode *compiler* and an
interpreter both execute as wasm. `demo-in-wasm.sh` assembles a guest with
`wat2wasm.wasm` (wabt, as wasm), then compiles+runs it with wasmtime.

## Why Pulley, and how it builds for wasip1

Cranelift has no `wasm32` *native* backend, so on wasm32 wasmtime's **Pulley**
("Portable, Universal, Low-Level Execution strategY") interpreter is the default
execution strategy — Cranelift emits Pulley bytecode and Pulley runs it. Both
are pure Rust and compile to wasm.

wasip1 is an "unsupported OS" to wasmtime's `sys` layer, which then selects its
**`custom`** backend (gated by the `custom-virtual-memory` feature). We supply
the required platform hooks as `#[no_mangle]` Rust fns in `runner/src/main.rs`:

- `wasmtime_mmap_new/_remap/_munmap/_mprotect/_page_size` — **malloc-backed**
  (64 KiB-aligned, raw base stashed before the region for `munmap`); `mprotect`
  is a no-op.
- `wasmtime_memory_image_*` — return NULL image (no copy-on-write; wasmtime
  copies instead).
- `wasmtime_tls_get/_set` — a 2-slot static array (single-threaded).

No signal/sync/fiber hooks are needed: **Pulley does explicit bounds checks**
(no hardware traps), and with the `std` feature `has_custom_sync` is forced off,
and `has_native_signals` stays off because wasip1 isn't a supported OS. The
runtime `Config` matches: `signals_based_traps(false)`, `memory_reservation(0)`,
`memory_guard_size(0)`, `memory_init_cow(false)`.

## Build shape

A tiny embedder (`runner/`) depends on the vendored `wasmtime` crate with
`default-features = false` + `["runtime","cranelift","pulley","wat","std",
"custom-virtual-memory"]`. wasmtime's own CLI is avoided (it needs
cap-std/rustix/native OS). ~5.5 MB. The largest, most capable runtime in the
floor — running under the ~688 KB tcc-built toywasm.
