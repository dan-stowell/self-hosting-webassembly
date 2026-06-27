# WAForth

A Forth interpreter/compiler **written directly in WebAssembly text format** —
it already lives in wasm, and emits wasm at runtime.

| | |
|---|---|
| Tier / effort | 0 / 2 |
| Impl language | WebAssembly (wat), ~3300 lines |
| Backend | direct (hand-written) |
| Status | ✅ **builds-to-wasm** (assembles); running needs a host |
| Artifact | `dist/waforth.wasm` (~16 KB) |

## What it is

The whole Forth system — dictionary, interpreter loop, and **compiler** — is
`src/src/waforth.wat`. Defining a word (`: NAME … ;`) makes the compiler emit
LEB128-encoded wasm opcodes into linear memory, building a complete child module
that the host instantiates via the `shell.load` import; words call each other by
`call_indirect` through a shared function table. So it's the project thesis in
its purest form: a wasm-emitting compiler that *is* a wasm module.

## Build

`build.sh` assembles the `.wat` to `dist/waforth.wasm` with `wat2wasm` (wabt).

## Running it (TODO)

Needs a host implementing 6 imports: `shell.emit/read/key/random/load/call`. The
hard one is `load` — it must instantiate a child module **sharing the parent's
linear memory and growing the shared function table**. Upstream ships hosts:
- `src/src/standalone/` — C host on the Wasmtime C-API.
- `src/src/web/` — browser/JS host.

A small host on a pure-Go runtime (wazero) or via wasm3's C API would make this
self-contained on the dev VM; not yet done (blocked only by writing the host,
not by the compiler).

## Host deps

`wat2wasm` (wabt) to assemble. A wasm host to run.

## Our changes

None yet.
