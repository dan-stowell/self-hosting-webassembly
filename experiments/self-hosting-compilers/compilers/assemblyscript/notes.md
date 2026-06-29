# AssemblyScript

A TypeScript-family language that compiles to WebAssembly. **The flagship
self-hosting result**: a production language whose compiler runs as wasm with
**no LLVM and no native code at all**.

| | |
|---|---|
| Tier / effort | 0 / 2 |
| Impl language | "portable AssemblyScript" (a TS subset) |
| Backend | **Binaryen, shipped as wasm** (the `binaryen` npm package), called via its C-API |
| Status | ✅ **self-hosting to wasm** — byte-identical fixed point, verified |
| Artifact | `dist/asc.wasm` (~0.9 MB) + `dist/asc.wasm.js` loader |

## Why this is the holy grail

The recurring wall in this suite is native-backend dependence (LLVM/Binaryen
FFI/linker). AssemblyScript has **none**: its only runtime deps are `binaryen`
(an Emscripten build of Binaryen — itself a wasm module) and `long`. When asc
compiles its own source to wasm, every Binaryen C-API call becomes a **wasm
import**, satisfied by `binaryen.wasm`. Two wasm modules, no native code.
`grep llvm package-lock.json` → zero hits.

## Self-hosting — verified

`build.sh` runs upstream's own bootstrap. Verified on this machine:

```
# JS build of asc compiles asc's source -> assemblyscript.release.wasm
# that wasm compiler recompiles asc's source -> ...release-bootstrap.wasm
$ cmp build/assemblyscript.release.wasm build/assemblyscript.release-bootstrap.wasm
  => identical            # stable fixed point: asc.wasm reproduces itself byte-for-byte

# functional: the wasm compiler compiling a program
$ node bin/asc fib.ts --wasm build/assemblyscript.release.js -o fib.wasm -O
$ node -e '...instantiate fib.wasm...'   =>  fib(10) = 55
```

Upstream CI runs the full compiler test suite *through* the wasm-built compiler
(`.github/workflows/test.yml` `bootstrap` job), so this isn't a toy path.

## Host deps

Node ≥ 20.19 + npm (a pinned Node is kept in `tools/`, git-ignored). No LLVM,
no compilers, no native modules.

## Our changes

None — upstream already self-hosts to wasm. The work here is integration.
