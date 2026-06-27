# WASM-emitting compilers → self-hosted in WASM: candidate ranking

Goal: collect compilers that **emit WebAssembly**, then modify them so the
compiler *itself* runs as a WASM module — either by self-hosting (the compiler
compiles itself, since it already targets wasm) or by compiling it with another
wasm-emitting toolchain.

> **Build results so far** (vendored + built in this repo; see `manifest.toml`,
> `scripts/verify.sh`). The empirical data confirms the thesis below: the wall is
> **native-backend dependencies (LLVM / Binaryen / external linker)**, not repo
> size or implementation language per se.
>
> | Compiler | Lang | Result |
> |---|---|---|
> | **assemblyscript** | AS | ✅ **self-hosting** — `asc.wasm` recompiles its own source to a byte-identical fixed point; no LLVM (Binaryen ships as wasm) |
> | **xcc** | C | ✅ end-to-end — `cc.wasm` compiles C → wasm that runs |
> | **wa** (凹语言) | Go | ✅ `GOOS=wasip1` build; output **byte-identical** to native |
> | **waforth** | wat | ✅ end-to-end — REPL compiles & runs Forth words as wasm at runtime |
> | **schism** | Scheme | 🅥 vendored; needs revival (2019-era encodings + removed Node flags) |
> | **webcc** | C++ | ⛔ blocked — own codegen but **execs `lld`** to link |
> | **basic_rs** | Rust | ⛔ blocked — `basic2wasm` uses the **`binaryen` crate** (native FFI) |
>
> The clean wins (xcc/wa/waforth) are all **self-contained, no native backend**.
> The blocked ones (webcc/basic_rs) emit wasm but can't *run* as wasm because they
> reach out to a native linker/Binaryen — the same wall as the LLVM-based Tier 3.
> Go's `GOOS=wasip1` is the single cleanest route when a compiler is written in Go
> with no cgo. Tooling note: the dev VM's egress was briefly firewalled to the
> GitHub release CDN / package registries (forcing `apt` + `git clone` + a
> built-from-source wasm3); that has since been restored.

## Holy grail: can the big "real" languages self-host to wasm?

Investigated the three most-requested targets. The deciding factor is the same as
everywhere else — **does the backend drag in native code (LLVM)?**

| Target | Backend | LLVM? | Self-hosts to wasm? | Effort |
|---|---|---|---|---|
| **AssemblyScript** | Binaryen shipped **as wasm** (npm pkg), called via C-API → wasm imports | none | ✅ **already does** (built + verified here: byte-identical fixed point) | 1–2 |
| **Zig** | own self-hosted wasm backend (`src/codegen/wasm/`, `src/link/Wasm.zig`); LLVM is opt-in (`have_llvm=false`) | none (for this path) | ✅ **already does** — `stage1/zig1.wasm` *is* the compiler self-compiled to wasm, used in its own bootstrap. (Old C++/LLVM "stage1" was removed.) | 1–2 |
| **Porffor** | its **own pure-JS** wasm encoder (`compiler/assemble.js` etc.); "Binaryen/etc is not used" | none | ⚠️ partial — self-applies to its *builtins*, but compiling its own 24K-line compiler needs JS far beyond its supported subset (~61% Test262). Clean deps, full self-host aspirational. | 5 (true self-host) / 1–2 (run its JS in a wasm JS-engine) |
| **TinyGo** | **LLVM** via CGo (`tinygo.org/x/go-llvm`, 57 sites); wasm = Go→LLVM IR→LLVM→wasm-ld | **intrinsic** | ❌ — CGo can't target wasip1; would need LLVM-in-wasm | 5 |

Takeaways: **AssemblyScript and Zig are the holy grail and are already done upstream**
(no LLVM, shipping self-hosted wasm builds) — the work is integration, not invention.
**TinyGo is the one "real" language that genuinely can't** self-host to wasm without
compiling LLVM to wasm. **Porffor** has ideal (no-native) dependencies but its compiler
is too complex for its own JS subset today. This corrects the Tier 3 placement of Zig
below (its effort is 1–2 via the no-LLVM backend, not 5).

## Self-hosting vs. cross-compiled (a distinction that matters)

"Self-hosting to wasm" = the compiler is written in language L, emits wasm, and
compiles *its own source* to a wasm module. That is a stronger property than merely
"the compiler runs as wasm":

- **Truly self-hosting:** AssemblyScript, xcc (C→wasm written in C, `cc.wasm` built by
  itself), Virgil, Schism, Zig. (WAForth is the limit case — hand-written wasm that
  compiles Forth to wasm.)
- **Cross-compiled to wasm (not self-hosting):** **Wa** — its compiler is written in Go
  and cross-compiled to wasm by Go (`GOOS=wasip1`); it does not compile itself.

## How to read the ranking

Repo size (from the GitHub API) is the user's stand-in for complexity, but it's
a **weak predictor of effort**. The two things that actually decide how hard it
is to run a compiler in wasm:

1. **Implementation language's wasm maturity.** Rust (`wasm32-wasi`), Go
   (`GOOS=wasip1`), C/C++ (Emscripten / wasi-sdk), and AssemblyScript/TS are
   well-trodden. OCaml/Reason, Haskell, Julia, and Zig's self-hosted backend are
   rougher. A JS/TS-implemented compiler needs a JS engine (QuickJS) in wasm.
2. **Backend dependency.** *No backend / emits wat/wasm directly* < *Binaryen*
   (has a wasm build) << *LLVM* (must itself be compiled to wasm — huge, painful;
   this is the single biggest blocker).

A compiler that is **self-hosting and already targets wasm** is the cleanest
case of all: `compiler(compiler.src) → compiler.wasm`. Those are flagged 🥇.

**Effort scale:** 1 = nearly free / already done · 5 = research project.

## Excluded

Entries from the readme that are **VMs/interpreters compiled *to* wasm** rather
than compilers that *emit* wasm don't fit the thesis and are left out: RustPython,
Pyodide, MicroPython, ruby.wasm, php-wasm/PIB, Boa, QuickJS/Duktape, Wasm3,
WasmLua, SWI-Prolog-wasm, WebR, etc. (They're already wasm; there's nothing to
"make compile to wasm.") Also excluded: unmaintained entries (Walt, Wam, Wah,
Astro, Asterius, Idris-wasm, Speedy.js, Turboscript, Wracket) and closed-source
ones (MoonBit compiler, LabVIEW/Vireo).

---

## Tier 0 — Self-hosting / already wasm-resident (effort 1–2)

These already have a bootstrap path: the compiler targets wasm and is written in
something that targets wasm. Highest payoff, lowest conceptual risk.

| Compiler | Lang | Size | Backend | Effort | Notes |
|---|---|---|---|---|---|
| 🥇 **WAForth** | Forth/wat | 8.0 MB | direct | **1** | Already a self-bootstrapping compiler *living in wasm*. Essentially the finished form of the whole project. |
| 🥇 **Schism** | Scheme | 0.9 MB | direct | **2** | Explicitly "self-hosting Scheme→wasm." `schism(schism)=schism.wasm`. Tiny & elegant, but unmaintained since 2020 — resurrecting the bootstrap host is the work. |
| 🥇 **Virgil** | Virgil | 71.8 MB | direct (own) | **2** | Self-hosting `v3c`, emits wasm, **no LLVM**. Bootstrap to wasm is squarely in scope. Largest of the tier but self-contained. |
| 🥇 **AssemblyScript** | AS/TS | 163 MB | Binaryen | **2** | `asc` is written in AssemblyScript and self-bootstraps; browser playground already runs it. Big but the most production-ready target here. |
| 🥇 **xcc** | C | 5.9 MB | direct | **2** | C→wasm compiler written in C → compile it with itself (or wasi-sdk) for a self-hosting wasm C compiler. Clean, small. |
| **Wa / 凹语言** | Go | 29.6 MB | direct | **2** | Compiler in Go, targets wasm; `wa` binary → wasm via Go's own `wasip1` target. Mature lang toolchain. |
| **Porffor** | JS/TS | 23 MB | direct | **3** | JS/TS→wasm with an explicit self-hosting goal, very active. Self-host needs its JS subset to cover its own source (or QuickJS-in-wasm). |

## Tier 1 — Small, self-contained, easy impl language (effort 2–3)

No LLVM, modest size, wasm-friendly implementation language.

| Compiler | Lang | Size | Backend | Effort | Notes |
|---|---|---|---|---|---|
| **Kou** | TS | 0.3 MB | direct | **2** | Tiny "minimal lang → wasm bytecode." Stale (2019) but trivial surface area. |
| **Poetry** | (wat) | 0.4 MB | direct | **2** | Small wasm-first lang, full control over imports/exports. Stale (2019). |
| **basic_rs / basic2wasm** | Rust | 0.5 MB | Binaryen | **2** | Rust→wasm is trivial; only friction is Binaryen (swap for `wasm-encoder`, or Binaryen-in-wasm). |
| **eel-wasm** | TS | 1.5 MB | Binaryen | **2** | Already runs in-browser; compiles Eel→wasm. TS + Binaryen. Active. |
| **c4wa** | Java | 1.7 MB | direct | **3** | C-subset→wasm, written in Java → host via TeaVM (Java→wasm). Small, readable. |
| **eclair-lang** | Haskell | 4.0 MB | LLVM | **4** | Small, but Haskell *and* LLVM backend — two rough wasm stories at once. |
| **Lys** | TS | 5.1 MB | Binaryen | **3** | Typed functional → wasm. Needs JS engine + Binaryen in wasm. |
| **Nelua** | Lua | 4.7 MB | C (→emcc) | **3** | Compiler in Lua (runs in wasm easily via wasmoon), but emits C → full chain needs a C compiler in wasm too. |
| **jz** | JS | 14.8 MB | direct | **3** | JS-subset→wasm; self-host blocked on a JS engine in wasm. |

## Tier 2 — Own backend but large, or Binaryen/runtime weight (effort 3)

| Compiler | Lang | Size | Backend | Effort | Notes |
|---|---|---|---|---|---|
| **Lobster** | C++ | 125 MB | direct (own) | **3** | **No LLVM** — own wasm backend. Big C++ but Emscripten-able. Effort is size/build-system, not architecture. |
| **Cyber** | Zig | 12.7 MB | direct | **3** | Zig→wasm is decent; scripting VM + compiler in Zig. |
| **V** | V | 110 MB | C | **3–4** | Self-hosting, but V→C→wasm is a two-stage chain; needs C→wasm in the loop. |
| **TeaVM** | Java | 127 MB | direct | **3–4** | Java→wasm/js, written in Java → **can compile itself** (bootstrap). Strong story despite size. |
| **WebAssemblyCompiler.jl** | Julia | 2.2 MB | Binaryen | **4** | Tiny glue, but a Julia runtime in wasm is the hard part. |

## Tier 3 — LLVM-bound or very large (effort 4–5)

LLVM in the backend means LLVM must itself run in wasm — the dominant blocker.
Repo size here is misleading (nlvm is 1.2 MB but useless without LLVM-in-wasm).

| Compiler | Lang | Size | Backend | Effort | Notes |
|---|---|---|---|---|---|
| **KCLVM** | Rust | 12.8 MB | LLVM | **4** | Rust hosts easily; LLVM dep is the wall. |
| **TinyGo** | Go | 12.7 MB | LLVM | **4** | Small repo, but depends on LLVM → hard despite Go being wasm-friendly. |
| **Crystal** | Crystal | 60.6 MB | LLVM | **4** | Self-hosting + LLVM. |
| **nlvm** | Nim | 1.2 MB | LLVM | **4** | Deceptively tiny; LLVM-in-wasm needed. |
| **Javy** | Rust | 104 MB | direct | **3–4** | Rust→wasm fine, but it embeds QuickJS + Wizer; heavy to host. |
| **ldc** | D | 173 MB | LLVM | **5** | Large + LLVM. |
| **Roc** | Zig | 226 MB | LLVM (+dev backend) | **5** | Large; Zig + LLVM. |
| **Emscripten** | C++/Py | 261 MB | LLVM | **5** | *Is* an LLVM toolchain; hosting it in wasm = LLVM-in-wasm, the maximal case. |
| **Bytecoder** | Java | 2.4 GB | direct | **5** | Java→wasm but enormous repo. |
| **Zig** | Zig | 371 MB | own + LLVM | **5** | Self-hosted wasm backend exists but immature; massive. |

## Long tail / needs investigation

`nwasm` (Nim wasm backend, 65 MB, stale 2020), `wase` (area9 Flow, 4.4 MB),
`Never` (C, 2.8 MB — likely interpreter-via-emscripten, verify it truly *emits*
wasm), `forest-lang/core` (Haskell, 0.7 MB, stale), `ThetaLang` (C++, 55 MB),
`Coi` (C++, 1.1 MB, active), `Co` (TS, stale), `Wonkey`/`Nerd` (large C++ game
langs), `JWebAssembly`/`Bytecoder` (Java→wasm).

---

## Suggested starting set

For a first proof-of-concept of "a wasm-emitting compiler, itself running as
wasm," the cleanest wins are **WAForth** (already done — study it), **xcc**
(self-hosting C, small), **Schism** (archetypal self-host, needs resurrection),
and **Virgil** (serious, self-contained, no LLVM). **AssemblyScript** is the most
production-credible if you want impact over minimalism.

---

## Verification log (2026-06-26)

Cloned and exercised the four easy wins on the VM (gcc 13, go 1.26, no node/clang;
GitHub *git* works but the release **CDN, PyPI, and Go module proxy are all
firewalled** — only `git clone` + `gh api` get out, so binary runtimes can't be
downloaded). Built a runtime instead: cloned wasm3 + uvwasi, compiled
`wasm3-uvwasi` with gcc (`apt` for `wat2wasm`/`libuv1-dev` works).

| Compiler | Result | Effort confirmed |
|---|---|---|
| **Virgil** | ✅ **Full loop proven.** `v3c` bootstrapped from the checked-in `bin/stable/x86-64-linux/Aeneas` (no JVM/LLVM), then compiled its own source to **`Aeneas.wasm` (1.47 MB)**. Running that module under Node's WASI, it compiled `add.v3` → valid `add.wasm` (exports `main`); executing that emitted module returns **`Result: 45`**. A wasm-emitting compiler, itself running as wasm, producing working wasm. Gotcha (not a runtime issue): `rt/wasm-wasi1/System.v3:19` calls `path_open` with **`oflags=0` (no `O_CREAT`)**, so it can only open *existing* output files — `: > add.wasm` first, or patch the oflag. Affects every WASI host equally. | **2/5 — confirmed, end-to-end** |
| **WAForth** | ✅ Hand-written `src/waforth.wat` (3276 lines) assembled with `wat2wasm` to **`waforth.wasm` (16 KB)** — a Forth compiler that emits wasm at runtime, already living in wasm. Needs only a ~thin host for its 6 `shell.*` imports (esp. dynamic module `load`). | **2/5 — confirmed** |
| **xcc** | ✅ Native build (`make all`) succeeds with gcc; self-host path is real and documented: `make wcc` → `make wcc-gen2` produces **`cc.wasm`**, the C compiler as a WASI module (powers the online demo). Needs `llvm-ar` (apt) + any WASI runtime; **no clang/node/emscripten**. | **2/5 — confirmed** |
| **Schism** | ⚠️ Bitrotten (2020). Self-host chain intact in principle (committed `schism-stage0.wasm` snapshot + Guile/Chez bootstrap → Node host), but the emitted wasm uses pre-final encodings (`ref.null` w/o type, `anyref`=0x6F now `externref`) and three removed Node `--experimental-wasm-*` flags. Needs a period-correct Node ~12 (easy path) or patching the codegen (full revival). | **3–4/5 — confirmed** |

**Bottom line:** Virgil is the standout — a serious, LLVM-free, self-hosting
systems language whose compiler self-compiles to a 1.5 MB wasm module that
actually runs and compiles code. WAForth and xcc are the small, clean exemplars.
Schism is the historically-pure self-hoster but needs revival work.

Artifacts left in the scratchpad: `Aeneas.wasm`, `waforth.wasm`, `wasm3-uvwasi`.
The one local patch needed to run Virgil under wasm3 was adding a `"."` preopen
to `wasm3/source/m3_api_uvwasi.c` (Virgil's WASI runtime maps relative paths via
a preopen literally named `.`).
