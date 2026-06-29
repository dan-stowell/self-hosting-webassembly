# wcpl — a self-hosted C→wasm compiler, compiled to wasm (phase 1)

| | |
|---|---|
| Upstream | false-schemers/wcpl @ `458a542`, BSD-like |
| Lang | C (a C-subset compiler + linker + libc, all in ~4 .c files) |
| Compiled to wasm by | **itself** (native seed → wcpl.wasm) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

The clearest phase-1 statement in the floor: a tiny compiler that **emits wasm**,
**compiled to wasm by itself**, running **as wasm** under the tcc-built toywasm,
**compiling C to wasm** — output that then runs in the same floor.

wcpl is a standalone C→WASM/WASI compiler (its own linker and libc included; the
libc is embedded in the binary as `res://`). It needs no external toolchain.

## The loop (`to-wasm.sh` + `demo-in-wasm.sh`)

1. **Seed:** build wcpl natively with any `cc` (`c.c l.c p.c w.c`).
2. **Self-host:** the native wcpl compiles wcpl's *own source* → `wcpl.wasm`
   (~313 KB) — a C→wasm compiler emitting itself as wasm.
3. **In the floor:** `wcpl.wasm` runs under the tcc-built toywasm and compiles
   `hello.c` → `hello.wasm`, which then runs under the same toywasm.

So the only native step is the one-time bootstrap seed; from there the compiler
is wasm and produces wasm, all hosted by the tcc-built interpreter.

## Bonus: the self-host fixpoint, in wasm

wcpl's headline property is that it reproduces itself bit-for-bit. That holds
*inside the floor* too: `wcpl.wasm` compiling its own source yields a `wcpl1.wasm`
**byte-identical** to `wcpl.wasm` (both 313594 bytes) — **verified**, the
compiler reproduced itself as wasm without leaving WebAssembly. It's gated behind
`WCPL_FIXPOINT=1` in the demo because compiling ~10 K lines of C under the
toywasm interpreter is slow: ~15m30s here (vs. well under a second natively) —
pure interpreter overhead, same fixpoint.

## Contrast with xcc/`cc.wasm`

Phase 1 already had xcc's `cc.wasm` hosted in toywasm
([toywasm/demo.sh](../toywasm/demo.sh)). wcpl adds a second, fuller C compiler
and a cleaner self-host story: the compiler that runs as wasm is the very
artifact it produced from its own source.
