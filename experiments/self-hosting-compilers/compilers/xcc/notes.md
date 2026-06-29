# xcc

Toy C compiler for x86-64/aarch64/riscv64 **and WebAssembly**, written in C.

| | |
|---|---|
| Tier / effort | 0 / 2 |
| Impl language | C |
| Backend | direct — own wasm emitter + linker, **no LLVM** |
| Status | ✅ **builds-to-wasm** (out of the box, no source changes) |
| Artifact | `dist/cc.wasm` (~336 KB) |

## Self-host-to-wasm path

`wcc` is xcc's C→wasm/WASI compiler. The native `wcc` (built with the host `cc`)
compiles `wcc`'s own C sources into **`cc.wasm`** — the C compiler itself as a
WASI module. This is exactly what powers the online demo at
tyfkda.github.io/xcc.

```
make wcc        # native wcc + wasm libc (needs llvm-ar)
make wcc-gen2   # wcc compiles its own sources -> cc.wasm
```

`build.sh` runs this and copies the result to `dist/cc.wasm`.

## Host deps

`gcc` (or clang), `make`, `llvm-ar` (Debian/Ubuntu: `apt install llvm`).
**No clang/node/emscripten needed.** A WASI runtime is needed only to *run* the
result.

## Verified (end-to-end)

`cc.wasm` running under `tools/wasm3` compiled a C program to wasm, and the
emitted module runs:

```
$ compilers/xcc/run-cc.sh hello.c hello.wasm   # cc.wasm compiles C -> wasm
$ tools/wasm3 hello.wasm
i=0 … i=4
```

`run-cc.sh` stages the toolchain at the guest paths cc.wasm expects
(`/usr/include`, `/usr/lib`, a writable `/tmp`; wasm3 maps `/` -> cwd). This is
exercised by `scripts/verify.sh`.

## Our changes

None yet — upstream builds to wasm as-is. Any future patches live as ordinary
commits over the vendored `src/` (see `git log -- compilers/xcc/src`).
