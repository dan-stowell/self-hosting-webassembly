# fizzy — a C++ wasm interpreter, compiled to wasm (phase 3)

| | |
|---|---|
| Upstream | wasmx/fizzy @ `5ce7e0b`, Apache-2.0 |
| Lang | C++17, **uses exceptions** (rides the eh/ multilib recipe) |
| Compiled to wasm by | wasi-sdk clang++ + the `eh/` exception multilib |
| Runs under | the EH-enabled tcc-built [toywasm](../toywasm/notes.md) |

fizzy is a fast, standalone C++ wasm interpreter. Compiled **to** wasm and run
**inside** the tcc-built toywasm, it executes a guest module —
interpreter-inside-interpreter. `demo-in-wasm.sh` assembles a guest with
`wat2wasm.wasm` (wabt, as wasm), then runs it with `fizzy-run.wasm`.

## Not the stock CLI — a tiny embedder

fizzy's own CLI, `fizzy-wasi`, links **uvwasi** → **libuv**, a native event-loop
stack that doesn't compile to wasm. But **libfizzy's core has no external deps**,
so we skip the CLI and build a ~60-line C-API embedder (`fizzy-run.c`):
load a module file, find an export, `fizzy_execute` it with i32 args, print the
result. That's enough to run fizzy *as* a wasm runtime under toywasm.

## Two libc++-modernization snags (both in `byte_char_traits.hpp`)

fizzy (2020) predates a couple of libc++ changes; both are fixed by one
force-included header rather than patching fizzy's sources:

1. **`std::char_traits<uint8_t>` was removed** (LLVM 19+ dropped the non-standard
   non-`char` specializations). fizzy's `bytes = std::basic_string<uint8_t>`
   needs it, so we supply a minimal specialization.
2. **`string_view::const_iterator` became a `__wrap_iter`, not a raw pointer**
   under libc++ ABI v2 (`_LIBCPP_ABI_USE_WRAP_ITER_IN_STD_STRING_VIEW`). fizzy's
   parser passes those iterators where `const uint8_t*` is expected. `string_view`
   is header-only, so we `#undef` that ABI flag before `<string_view>` is first
   included — restoring the pointer iterator with no ABI mismatch against the
   prebuilt libc++.

## Exceptions

Same recipe as [binaryen](../binaryen/notes.md): `-fwasm-exceptions
-mllvm -wasm-use-legacy-eh=false`, link `-L.../eh -lunwind`, and a pass-through
`wasm-opt` shim on `$PATH`. See memory `wasi-sdk-cpp-exceptions-recipe`.
