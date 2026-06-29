# WebAssembly runtimes through the bootstrap-floor lens

*Survey as of 2026-06-29.* The question for this thread is **not** "which wasm
runtime is fastest" — it's: starting from a bare machine (a Raspberry Pi, a
`FROM scratch` container, ultimately a minimal seed → tiny C compiler), what
would it take to

1. **build** a wasm runtime with a *minimal* compiler (ideally a tcc-class C
   compiler, not LLVM / cargo / a C++ toolchain), and
2. **run** it with as little underneath as possible (minimal libc, bare
   syscalls, freestanding), so that
3. once it runs, it can **execute the compiler(s) that build it** — closing the
   loop *inside* WebAssembly.

This is the [tiny-languages](https://github.com/altdansalt/tiny-languages)
bootstrap-floor lens (minimal seed → M2-Planet → GNU Mes → tcc → real
toolchain), pointed at runtimes instead of languages. `wasm3` already appears in
that project's verified list; here we ask what the *whole field* costs to
bootstrap.

## What makes a runtime bootstrappable

| Property | Bootstrap-friendly | Bootstrap-hostile |
|---|---|---|
| Impl language | **C** (a tiny C compiler can build it) | Rust / Go / C++ (each is its own bootstrap problem) |
| Execution strategy | **interpreter** or **wasm→C translator** (portable, no native codegen) | JIT / AOT (emits host machine code; needs host assembler/linker, arch-specific) |
| Dispatch | plain `switch`, or computed-goto **with a switch fallback** | hard dependence on compiler **TCO** (tail calls) or labels-as-values with no fallback |
| C features | C89/C99, ordinary `goto` | `_Atomic`, `__int128`, GCC IEEE flags, inline asm, `setjmp` on bare metal |
| Build system | `make`, or a single `cc *.c` | CMake-only, meson, cargo |
| Runtime deps | minimal/builtin libc, can run freestanding | full OS, libuv, glibc-isms |
| WASI | **yes** (a compiler needs file I/O to run inside the sandbox) | none (can't host a real toolchain) |

A note on tiny C compilers, since the choice of *seed* compiler matters:

- **tcc** — supports computed gotos (`&&label`/`goto *p`); does **not** do TCO;
  `_Atomic`/`__int128` unreliable/absent.
- **cproc**, **chibicc** — no computed gotos, no `__int128`; cproc has no
  `_Atomic`. So a computed-goto interpreter must fall back to `switch` for these.

The upshot: **wasm3's design (tail-call-threaded ops) needs compiler TCO that
none of tcc/cproc/chibicc provide** — it compiles, but overflows the native
stack on real programs. That single fact reorders the whole field.

## The field (ordered by bootstrap relevance)

| Runtime | Lang | Strategy | Build / critical deps | Tiny-C-buildable? | Runtime deps | WASI | Status (2026) |
|---|---|---|---|---|---|---|---|
| **w2c2** `turbolent/w2c2` | C89 | wasm→C translator | make/cmake; no LLVM | **Likely — best** (C89 in/out, ordinary `goto`) | translated C + small rt lib; hosted libc | **Yes** (ran clang, RustPython) | Active |
| **toywasm** `yamt/toywasm` | C11 | pure interpreter (no big-switch, no labels-as-values) | CMake; no LLVM | **Likely** (no TCO/goto blocker; C11 `_Atomic` only on threads path) | freestanding core (NuttX/ESP32); POSIX for WASI | **Yes, full** (preview1 + threads) | **Active** v76 (2026-05) |
| **wac / wax** `kanaka/wac` | C (gnu99) | pure interpreter (`while`+`switch`) | make; libedit/SDL2 optional | **Yes — friendliest language-wise** (no goto/`__int128`/`_Atomic`) | standard libc; can run freestanding (fooboot) | Partial (MVP) | Dormant |
| **WAMR / iwasm** `bytecodealliance/wasm-micro-runtime` | C | classic interp (switch) / fast interp / Fast-JIT / LLVM-JIT / AOT | CMake; **LLVM only for JIT/AOT**; interp build needs none | **Likely (interp-only, LLVM off, `LABELS_AS_VALUES=0`)** | bare-metal/RTOS; builtin libc (~3.7 KB) or libc-wasi | **Yes** (self-contained libc-wasi, no libuv) | **Very active** 2.4.4 |
| **wasm3** `wasm3/wasm3` | C | fast interpreter (tail-call-threaded "M3") | CMake; no LLVM | **Compiles yes / runs NO** — needs compiler **TCO** | smallest (~64 KB / ~10 KB RAM); bare-metal, Pi | Partial (builtin) / fuller via uvwasi (libuv) | Min-maintenance (tag v0.5.0 2021) |
| **wasm2c** `WebAssembly/wabt` | tool C++ / output C99–C11 | wasm→C translator | CMake (wabt is C++); no LLVM | **Unlikely** — output needs C99/C11, `_Atomic` (threads), GCC IEEE flags, `setjmp` | `wasm-rt` + libc | No core (BYO shim) | **Very active** wabt 1.0.41 |
| **wasmi** `wasmi-labs/wasmi` | Rust | pure interpreter | cargo | **No** (Rust) | `no_std`-capable | Yes (opt-in) | Active, v1.0 |
| **fizzy** `wasmx/fizzy` | C++17 | pure interpreter | CMake + C++17 | **No** (C++) | hosted C++ | Partial | Active |
| **stitch** `makepad/stitch` | Rust | fast interpreter (threaded + tail calls) | cargo | **No** (Rust) | std | No | Experimental |
| **wazero** `tetratelabs/wazero` | Go | interpreter + AOT machine code | Go toolchain; zero deps, no cgo | **No** (Go; compiler mode emits native) | minimal Go, scratch images | Yes (wasip1) | **Active** v1.12 |
| **wasmtime** `bytecodealliance/wasmtime` | Rust | optimizing JIT/AOT (Cranelift) + Pulley interp | cargo; no LLVM | **No** (Rust; emits machine code) | full OS; `no_std` drops JIT | Yes (reference-quality, WASI 0.2) | Very active |
| **wasmer** `wasmerio/wasmer` | Rust | JIT/AOT (Singlepass/Cranelift/LLVM) | cargo; LLVM for that backend | **No** (Rust) | full OS | Yes (+WASIX) | Active |
| **WasmEdge** `WasmEdge/WasmEdge` | C++ | interpreter + LLVM AOT/JIT | **CMake** + C++ (+LLVM default) | **No** (C++/STL) | full OS | Yes | Active |
| **WAVM** `WAVM/WAVM` | C++ | optimizing JIT only (all LLVM) | CMake + **full LLVM** + C++ | **No** | 64-bit VM space; OS | Yes | Revived 2026 |
| **life** / **wagon** (Go) | Go | interpreter | Go toolchain | **No** | Go runtime | No | Dormant / **archived** |
| **warpy** `kanaka/warpy` | RPython | interpreter / RPython-JIT | RPython toolchain | **No / N/A** | CPython or translated bin | No | Dormant |

Honorable mention — **WARP** `wasm-ecosystem/wasm-compiler` (C++14): a rare
bare-metal single-pass wasm→machine-code compiler (~10 KB compile heap, ~187 KB
stripped, active 2026-06), but C++ and no documented WASI. And **`nodejs/uvwasi`**
is the libuv-based WASI host that both wasm3 and WAMR use for "full" WASI —
pulling it in pushes you off the minimal-dependency end (WAMR's self-contained
`libc-wasi` is the way to avoid it).

## Two bootstrap strategies

There are really **two different shapes** of "run wasm with nothing else," and
they bottom out very differently:

### A. Translate — `wasm → C → tiny C compiler` (no runtime at all)
`w2c2` (and `wasm2c`) turn a `.wasm` module into C. Compile that C with whatever
compiler you've bootstrapped, and you have a native binary — **no interpreter,
no JIT, no engine to maintain**. This is the most bootstrap-friendly shape, and
it's not hypothetical: **w2c2 has been used to compile and run `clang` and
RustPython**. It's also *exactly* how Zig bootstraps (wasm2c on `zig1.wasm` →
C → cc), which we proved in the archived
[self-hosting-compilers](../experiments/self-hosting-compilers/compilers/zig/notes.md)
thread. The catch: the *generated* C must stay within the tiny compiler's
feature set — `w2c2`'s C89 output is the friendly case; `wasm2c`'s C11+atomics+
IEEE-flags output is not.

### B. Interpret — one small C interpreter, build once, run everything
`toywasm` / `wac` / `WAMR`-classic give you a single portable C interpreter.
Build it once with a tiny C compiler, and it runs *any* wasm — including a wasm
toolchain. This is the better shape if you want a persistent wasm environment
(a REPL, a sandbox) rather than per-module native binaries.

`wasm3` is the famous small interpreter, but its TCO dependence disqualifies it
from the *tiny-compiler* stage — it only becomes usable once a TCO-capable
compiler (gcc/clang) already exists. So for the **floor**, the interpreter is
`toywasm` (most complete + maintained) or `wac`/`wax` (simplest C), not wasm3.

## Closing the loop: a runtime running the compiler that builds it

The goal's third clause — the runtime can run the compilers that build it — is
where it gets interesting. Two routes:

- **C-compiler-as-wasm under the interpreter.** Run a C→wasm compiler *inside*
  the interpreter, feed it the interpreter's own C source, get a `.wasm` of the
  interpreter, run that under the native interpreter → wasm-in-wasm. The blocker
  we already hit in the compilers thread: small C-as-wasm compilers (xcc's
  `cc.wasm`) **can't compile production C** — they lack `__int128`, `_Atomic`,
  attributes (we proved this trying to compile Zig's generated C). The realistic
  C-as-wasm compiler is **wasi-sdk clang**, which w2c2 has already shown can run.
- **Translate then self-host.** Use w2c2 to turn `clang.wasm` (wasi-sdk) into C,
  build it with tcc/gcc → a native clang that emits wasm → compile the runtime's
  own source → loop closed. Heavier, but each link is demonstrated.

The minimal-seed precedent (`bootstrappable.org` / stage0 / GNU Mes) has **no
wasm runtime in the chain today** — composing one would be novel. The nearest
prior art is w2c2 having run clang.

## Recommended next experiments (in order)

1. **wac/wax with tcc** — strip the Makefile's `-m32`/readline/SDL, build `wax`
   with `tcc`, run a hand-written `.wasm`. Smallest possible "tiny compiler
   builds a wasm interpreter" proof. (Caveat: `__builtin_clz/ctz/popcount` —
   check tcc coverage.)
2. **toywasm with tcc/cc** — build it, run a WASI program (e.g. our xcc
   `cc.wasm` or a hello), confirm full WASI file I/O works. This is the real
   candidate for a persistent wasm floor.
3. **w2c2 round-trip** — translate a `.wasm` → C → compile with tcc → run.
   Then translate `toywasm.wasm`/`wac.wasm` and run *that* — interpreter-via-
   translation, no engine binary.
4. **WAMR interp-only, LLVM off** — `-DWAMR_BUILD_INTERP=1` with JIT/AOT off and
   `WASM_ENABLE_LABELS_AS_VALUES=0`; measure how much of the CMake/platform-shim
   surface a tcc build actually needs, and exercise self-contained `libc-wasi`.
5. **The loop** — run wasi-sdk `clang.wasm` under toywasm/WAMR (or via w2c2) and
   have it compile a runtime's own C source to wasm; run the result. This is the
   "builds itself inside WebAssembly" milestone.

Each becomes a `runtimes/<name>/` entry (UPSTREAM pin + build notes + what broke)
as it's attempted — mirroring the compilers thread's layout.
