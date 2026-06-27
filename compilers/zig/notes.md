# zig

The [Zig](https://ziglang.org) compiler — and the answer to "is Zig stage1
useful, and can it emit WebAssembly?" **Yes to both.**

| | |
|---|---|
| Tier / effort | 0 / 3 |
| Impl language | Zig |
| Backend | **direct, no LLVM** — Zig's own self-hosted backend |
| Status | ✅ **self-hosting + builds-to-wasm** (proven end-to-end here) |
| Artifact | `zig1.wasm` (committed, 3.2 MB) → bootstraps `dist/zig2` |
| Pin | ziglang/zig @ `738d2be9` (2025-11-26), `0.14.0-dev.bootstrap` |

## The two things this proves

1. **Zig is genuinely self-hosting *to wasm*, no LLVM.** `zig1.wasm` is the Zig
   compiler compiled to a single WebAssembly module by Zig itself, using its own
   `-ofmt=wasm` backend. It is the upstream bootstrap seed (`stage1/zig1.wasm`),
   committed here as the trophy artifact. `have_llvm = false` throughout.

2. **The wasm form bootstraps a full native compiler that itself emits wasm.**
   Running upstream's `bootstrap.c` turns `zig1.wasm` into `zig2`, a complete
   no-LLVM Zig compiler. We then drove `zig2` to emit working WebAssembly.

## Bootstrap chain (all in `bootstrap.c`, no LLVM, no network after clone)

```
zig1.wasm  --wasm2c-->  zig1.c (253 MB)  --gcc-->  zig1   (slow interp-ish compiler)
zig1  compiles src/main.zig  -ofmt=c     ->        zig2.c (187 MB of C)
gcc   zig2.c + compiler_rt.c                       zig2   (22.7 MB native compiler)
```

`wasm2c` (a ~2k-line C file, `stage1/wasm2c.c`) is the only "interpreter" link,
and it exists purely to make the wasm runnable by a C toolchain. There is **no
LLVM anywhere** in this chain — that's the whole point of `dev = .core` /
`have_llvm = false`.

Cost: ~10 min wall and ~6 GB peak RAM (the final `gcc` over 187 MB of generated
C). This is why Zig is **not** wired into the fast `scripts/verify.sh` or the
Docker smoke build — run `compilers/zig/build.sh` explicitly.

## What `zig2` can do (verified — `compilers/zig/test.sh`)

| capability | result |
|---|---|
| native executable | ✅ compiles & runs (`hello from zig2`) |
| `wasm32-wasi` program | ✅ emits wasm; runs under `tools/wasm3` (`hello from zig2`) |
| `wasm32-freestanding` lib | ✅ emits wasm; `add(20,22) = 42` callable from JS |

Caveats of this bootstrap build (expected, not bugs):
- `dev = .core` trims subcommands — `zig2 version` and the package manager are
  gated off. It's a *compiler*, not the full CLI.
- Debug-mode freestanding wasm traps on call (stack/safety instrumentation
  expects a runtime that sets the stack pointer); build with `-OReleaseSmall`
  (or wire up the stack) and exports work — hence `add(20,22)=42`.
- `zig1.wasm` run *directly* under wasm3 can compile with `-ofmt=c`, but
  building a wasm exe needs `ar` to archive wasi-libc, which the trimmed
  bootstrap refuses (`ar_command` unsupported). The native `zig2` is the right
  tool for emitting wasm.

## Why this entry is thin (not "vendor pristine")

The full tree is ~260 MB of source (`lib/` 233 MB — mostly libc for ~40
targets — plus `src/` 25 MB) and the bootstrap needs ~6 GB RAM. Vendoring that
inline would dwarf the rest of the suite and break the lightweight clone/Docker
story. So we commit only the irreplaceable self-hosted artifact (`zig1.wasm`)
and the recipe (`bootstrap.c`); `build.sh` clones the pinned ref for the bulk
and verifies the cloned `zig1.wasm` matches the committed one.

## Host deps

`git` (to fetch the pinned tree), `gcc`/`cc`, ~6 GB RAM, ~10 min. A WASI runtime
(`tools/wasm3`) only to *run* the emitted wasm. No LLVM, no Node for the build.

## Relation to the suite's goals

- **Goal 1 (find self-hosting wasm compilers):** Zig qualifies — self-hosting,
  emits wasm, no LLVM. `zig1.wasm` is the compiler-as-wasm.
- **Goal 3 (make the "real" languages self-host to wasm):** already done
  upstream; this entry reproduces and proves it from the wasm seed. Alongside
  AssemblyScript, Zig is the no-LLVM holy grail (TinyGo, by contrast, is
  LLVM-intrinsic).
