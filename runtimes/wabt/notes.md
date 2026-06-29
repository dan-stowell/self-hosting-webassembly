# wabt — the wasm toolbox, compiled to wasm (roadmap phase 2)

| | |
|---|---|
| Upstream | WebAssembly/wabt @ `23b62e9` (2026-06-27), Apache-2.0 |
| Lang | C++ (builds **exception-free**: `WITH_EXCEPTIONS=OFF`) |
| Compiled to wasm by | wasi-sdk clang++ (`wasi-sdk-p1.cmake` toolchain) |

Six wabt tools, compiled **to** wasm and run **inside** the tcc-built
[toywasm](../toywasm/notes.md), operating on wasm:

| tool (as wasm) | size | does |
|---|---|---|
| `wat2wasm`     | 1.3 MB | assemble `.wat` → `.wasm` |
| `wasm2wat`     | 1.1 MB | disassemble `.wasm` → `.wat` |
| `wasm-objdump` | 924 KB | inspect sections/imports/exports |
| `wasm-validate`| 1.1 MB | validate a module |
| `wasm-strip`   | 877 KB | strip custom sections |
| `wat-desugar`  | 1.3 MB | desugar `.wat` |

`demo-in-wasm.sh` round-trips a module inside the sandbox: `wat2wasm.wasm`
assembles it, `wasm2wat.wasm` disassembles it back, `wasm-objdump.wasm` inspects
it, and toywasm runs the result.

## Why this one worked where C++ usually doesn't

wasi-sdk 33's libc++ is built **without exceptions** (`__cxa_throw` is undefined;
`-fwasm-exceptions` needs runtime bits the sysroot lacks). That blocks most C++
→ wasm. But wabt is deliberately exception-free (`option(WITH_EXCEPTIONS OFF)`,
no `try`/`catch`/`throw` in its own source), so it compiles cleanly against the
no-exceptions libc++. (Contrast **binaryen**, which uses exceptions and would
need an exception-enabled sysroot — see [ROADMAP.md](../ROADMAP.md).)

## What it took

- `WITH_EXCEPTIONS=OFF`, `BUILD_TESTS=OFF`, `BUILD_LIBWASM=OFF`, and the
  `wasi-sdk-p1.cmake` toolchain file.
- A shallow clone omits submodules; only one single-header dep (`picosha2.h`,
  for `sha256.cc`) is actually needed to build these tools — `to-wasm.sh` fetches
  it directly rather than pulling wabt's large submodules (testsuite, gtest).
