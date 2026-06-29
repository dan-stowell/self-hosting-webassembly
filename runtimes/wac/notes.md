# wac / wax — Path A: the smallest interpreter a tiny compiler can build

| | |
|---|---|
| Upstream | kanaka/wac @ `8c9da26` (2024-08-09), MPL-2.0 |
| Strategy | pure interpreter (`while` + `switch` dispatch) |
| Built with | **tcc 0.9.27** — `wax` (minimal WASI variant), 78 KB |
| WASI | partial, **legacy `wasi_unstable` ABI** |

## What was proven (Path A — smallest proof)

- **tcc builds a WebAssembly interpreter.** `wax` (the no-REPL, no-SDL variant
  of wac) compiles with tcc into a ~78 KB native interpreter.
- **It executes wasm.** A hand-written `wasi_unstable` module
  ([hello_unstable.wat](hello_unstable.wat)) runs under it and prints
  `hello from wax, a wasm interpreter built by tcc`. See `./run.sh`.

This is the floor of Path A: a tiny C compiler is enough to build something that
runs WebAssembly.

## The three tcc gaps (what it took)

1. **readline include** — `platform.h` includes `editline/readline.h` for the
   libc platform, but only the REPL (`wac.c`) uses it. `build.sh` guards the
   include and builds `wax` with `-DNO_READLINE` — no readline dependency.
2. **bit builtins** — `wa.c` uses `__builtin_clz/ctz/popcount(ll)` for the wasm
   clz/ctz/popcount ops; tcc 0.9.27 doesn't provide them. We `-include` a 7-line
   shim ([tcc_builtins.h](tcc_builtins.h)) with portable versions (whose `clz(0)
   == width` happens to match wasm semantics).
3. **`-rdynamic`** — wac resolves a module's host imports by `dlsym`-ing the
   running binary, so the WASI functions must be in the dynamic symbol table.
   tcc accepts `-rdynamic` and it works.

## The two honest caveats (why wax is a stepping-stone, not a floor)

- **Legacy WASI ABI, incomplete.** wac's `wasi.c` implements the old
  `wasi_unstable` names (`_wasi_unstable__fd_read_`, …) and lacks calls like
  `fd_filestat_get`. Modern toolchains emit `wasi_snapshot_preview1`, so wax
  **cannot** run our xcc `cc.wasm` or other current WASI modules — only
  `wasi_unstable` ones, and only within its partial coverage.
- **32-bit ABI assumption.** The upstream Makefile hardcodes `-m32`: wac's
  host-call thunking marshals arguments as 32-bit. Built 64-bit (as tcc does
  here by default), the program logic still runs and prints correctly, but a
  host call like `fd_write` (whose C signature has a 64-bit `size_t` count)
  over-runs *after* the correct output. Clean end-to-end execution wants a
  32-bit toolchain (`tcc -m32` + i386 multilib), which we did not pursue.

## Takeaway

`wax` earns its place as *the* minimal "tiny compiler → wasm interpreter" proof,
but its legacy/partial WASI and 32-bit assumption mean it can't host a real
modern toolchain. For a persistent floor that runs current WASI programs
(including a compiler), see [toywasm](../toywasm/notes.md) — Path B.
