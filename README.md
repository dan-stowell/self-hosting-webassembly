# self-hosting-webassembly

A suite of compilers that **emit WebAssembly**, collected and modified so that
each compiler *itself* compiles to / runs as a wasm module — by self-hosting
(the compiler compiles its own source, since it already targets wasm) or by
building it with another wasm-emitting toolchain.

- **[candidates.md](candidates.md)** — the full ranking of WASM-emitting
  compilers by real effort, plus a verification log for the easy wins.
- **[manifest.toml](manifest.toml)** — index of the suite with upstream pins and
  build status.

## Layout

```
compilers/<name>/
  UPSTREAM        # upstream url, pinned commit, vendored date, license
  build.sh        # reproducibly build the compiler-as-wasm into dist/
  notes.md        # tier, effort, self-host path, what we patched & why
  src/…           # vendored pristine snapshot, edited in place
scripts/vendor.sh # import / re-import an upstream snapshot
manifest.toml     # the index
candidates.md     # the ranking + rationale
```

We **vendor** rather than submodule: each compiler is a pristine snapshot
(upstream history stripped) edited in place, so our modifications are ordinary,
diffable commits in this repo and one `git clone` yields the whole buildable
suite. See the top of `candidates.md` for why effort is driven by
implementation-language wasm-maturity and LLVM-dependency, not repo size.

## Add a compiler

```sh
scripts/vendor.sh <name> <git-url> [ref]   # snapshot upstream into compilers/<name>/src
# then write compilers/<name>/build.sh + notes.md, and add it to manifest.toml
```

To see just our delta over upstream for a compiler:

```sh
git log  -- compilers/<name>/src           # our commits on the vendored source
```

## Build a compiler-as-wasm

```sh
compilers/<name>/build.sh                  # output lands in compilers/<name>/dist/
```

Built artifacts (`dist/`, in-tree object files) are git-ignored and reproducible.

## Run / verify

A local wasm3 WASI runtime (built from source, since the dev VM can't reach the
GitHub release CDN) runs the artifacts:

```sh
scripts/build-wasm3.sh    # -> tools/wasm3  (needs gcc + libuv1-dev)
scripts/verify.sh         # build every builds-to-wasm compiler and smoke-test it
```

`verify.sh` currently checks: `cc.wasm` runs as the C compiler, `wa.wasm`
compiles a program to wasm, and `waforth.wasm` assembles.

## Status

| Compiler | Lang | Tier/Effort | Status |
|---|---|---|---|
| [xcc](compilers/xcc/notes.md) | C | 0 / 2 | ✅ builds-to-wasm; **end-to-end**: `cc.wasm` compiles C → wasm that runs |
| [wa](compilers/wa/notes.md) (凹语言) | Go | 0 / 2 | ✅ builds-to-wasm (`dist/wa.wasm`); output **byte-identical** to native |
| [waforth](compilers/waforth/notes.md) | wat | 0 / 2 | ✅ builds-to-wasm (`dist/waforth.wasm`); running needs a host |
| virgil | Virgil | 0 / 2 | planned (proven in scratch) |
| schism | Scheme | 0 / 4 | planned (needs revival) |

Host tooling used so far (all from the distro or built from source — note the
GitHub release CDN / PyPI / Go module proxy are firewalled on the dev VM, so
prefer `apt` + `git clone`): `gcc`, `make`, `llvm-ar`, `wat2wasm` (wabt),
`node`, and a `wasm3` runtime built from source.
