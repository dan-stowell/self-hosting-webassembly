# self-hosting-webassembly

A suite of compilers that **emit WebAssembly**, collected and modified so that
each compiler *itself* compiles to / runs as a wasm module — by self-hosting
(the compiler compiles its own source, since it already targets wasm) or by
building it with another wasm-emitting toolchain.

- **[candidates.md](candidates.md)** — the full ranking of WASM-emitting
  compilers by real effort, plus a verification log for the easy wins.
- **[manifest.toml](manifest.toml)** — index of the suite with upstream pins and
  build status.

## Goals

Three related but distinct threads:

1. **Find all the truly self-hosting wasm compilers** — a compiler written in
   language L that emits wasm and compiles *its own source* to a wasm module.
   Confirmed so far: **AssemblyScript**, **xcc**, **Zig**, **Virgil**, **Schism**,
   and (as a limit case) **WAForth**. Note **Wa** is *not* self-hosting — it's a
   Go compiler cross-compiled to wasm. (See candidates.md "self-hosting vs.
   cross-compiled".)
2. **Use those compilers to compile more tools/compilers to wasm** — e.g.
   `cc.wasm` (xcc) compiling other C projects to wasm (demoed end-to-end).
3. **Make the big "real" languages self-host to wasm** — AssemblyScript ✅ (done,
   vendored) and Zig ✅ (done upstream: `zig1.wasm`) are the holy grail and need
   no LLVM. **TinyGo ❌** is LLVM-intrinsic (can't, short of LLVM-in-wasm).
   **Porffor** has ideal no-native deps but its compiler outgrows its own JS
   subset (full self-host aspirational).

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

Two levels of checking:

- **`scripts/verify.sh`** (fast smoke test, 6/6): each compiler *running as wasm*
  produces working output — `cc.wasm` compiles C→wasm that runs, `wa.wasm`
  compiles a program, `waforth` compiles & runs a Forth word, `schism` self-hosts
  through its stages, `asc.wasm` compiles TS→wasm that runs `fib(10)=55`.
- **`scripts/confirm-selfhost.sh`** (slower, the gold standard): the genuinely
  self-hosting compilers *reproduce themselves*:
  - **AssemblyScript** — `asc.wasm` recompiles its own source to a **byte-identical**
    919,676-byte fixed point.
  - **xcc** — `cc.wasm` (which is `wcc` compiled from `wcc`'s own C source) compiles
    C to a working wasm module.
  - **Schism** — `stage0.wasm` compiles `compiler.ss` through stage1→stage2.

### Reproducibility (container)

```sh
docker build -t self-hosting-wasm .
```

The build installs the toolchain on a clean `ubuntu:24.04`, builds the wasm3
runtime from source, and runs `scripts/verify.sh` — so a successful image build
*is* the proof that the suite builds to wasm from scratch (3/3 pass).

## Status

| Compiler | Lang | Tier/Effort | Status |
|---|---|---|---|
| [assemblyscript](compilers/assemblyscript/notes.md) | AS (TS subset) | 0 / 2 | ✅ **self-hosting** — byte-identical fixed point; no LLVM (Binaryen-as-wasm) |
| [xcc](compilers/xcc/notes.md) | C | 0 / 2 | ✅ builds-to-wasm; **end-to-end**: `cc.wasm` compiles C → wasm that runs |
| [wa](compilers/wa/notes.md) (凹语言) | Go | 0 / 2 | ✅ builds-to-wasm (`dist/wa.wasm`); output **byte-identical** to native |
| [waforth](compilers/waforth/notes.md) | wat | 0 / 2 | ✅ **end-to-end**: REPL compiles & runs Forth words as wasm at runtime |
| [schism](compilers/schism/notes.md) | Scheme | 0 / 3 | ✅ **self-hosting** (revived under pinned Node 12) |
| virgil | Virgil | 0 / 2 | planned (proven in scratch) |
| webcc / basic_rs | C++ / Rust | 1 / 3 | ⛔ vendored-blocked (external lld / Binaryen FFI) |

Host tooling used so far (all from the distro or built from source — note the
GitHub release CDN / PyPI / Go module proxy are firewalled on the dev VM, so
prefer `apt` + `git clone`): `gcc`, `make`, `llvm-ar`, `wat2wasm` (wabt),
`node`, and a `wasm3` runtime built from source.
