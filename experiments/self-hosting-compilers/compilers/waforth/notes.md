# WAForth

A Forth interpreter/compiler **written directly in WebAssembly text format** —
it already lives in wasm, and emits wasm at runtime.

| | |
|---|---|
| Tier / effort | 0 / 2 |
| Impl language | WebAssembly (wat), ~3300 lines |
| Backend | direct (hand-written) |
| Status | ✅ **builds-to-wasm + runs end-to-end** via the standalone host |
| Artifact | `dist/waforth.wasm` (~16 KB core) + `dist/waforth` (REPL host) |

## What it is

The whole Forth system — dictionary, interpreter loop, and **compiler** — is
`src/src/waforth.wat`. Defining a word (`: NAME … ;`) makes the compiler emit
LEB128-encoded wasm opcodes into linear memory, building a complete child module
that the host instantiates via the `shell.load` import; words call each other by
`call_indirect` through a shared function table. So it's the project thesis in
its purest form: a wasm-emitting compiler that *is* a wasm module.

## Build

`build.sh` assembles the `.wat` to `dist/waforth.wasm` with `wat2wasm` (wabt).

## Running it (done)

`build-host.sh` builds upstream's standalone REPL host (`src/src/standalone/`,
a C host on the Wasmtime C-API that implements the 6 `shell.*` imports — the
hard one being `load`, which instantiates child modules sharing the parent's
memory + function table). The Forth compiler itself runs as wasm inside it:

```
$ printf ': SQUARE DUP * ;\n7 SQUARE .\n10 FIB .\nBYE\n' | dist/waforth
WAForth (0.20.1)
ok
49 ok        # SQUARE was compiled to wasm at runtime, then executed
89 ok        # recursive FIB likewise
```

`scripts/verify.sh` runs this check when `dist/waforth` has been built (the host
needs the wasmtime C-API, which `build-host.sh` downloads).

## Host deps

`wat2wasm` (wabt) to assemble. A wasm host to run.

## Our changes

None yet.
