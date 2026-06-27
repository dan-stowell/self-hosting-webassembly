# Schism

The archetypal self-hosting compiler: a subset of R6RS Scheme → WebAssembly,
written in that same subset. Google project, **unmaintained since 2020**.

| | |
|---|---|
| Tier / effort | 0 / 4 |
| Impl language | Scheme |
| Backend | direct (its own wasm byte emitter) |
| Status | ✅ **self-hosting** (under a pinned Node 12) — revived |
| Artifact | `schism-stage0.wasm` (committed; the Scheme→wasm compiler as wasm) |

## Bootstrap chain

1. A host Scheme (Guile, or the original Chez) runs `schism/compiler.ss` to
   produce `schism-stage0.wasm` (a snapshot of this is committed at repo root).
2. `rt/rt.mjs` (Node) instantiates stage0 and supplies the runtime imports.
3. stageN compiles `compiler.ss` → stageN+1; stage2≡stage3 ⇒ self-hosting.

## Why it doesn't run as-is (2026)

- Codegen emits **pre-final** wasm: `ref.null` with no type immediate
  (`compiler.ss` ~1571), and `anyref` = `0x6F` (now `externref`). The committed
  `schism-stage0.wasm` therefore fails validation on any current V8/Node.
- The wrapper scripts pass three removed Node flags
  (`--experimental-wasm-anyref`, `--experimental-wasm-return-call`,
  `--experimental-modules`); modern Node errors on unknown `--experimental-*`.
- ESM extensionless imports and an ancient `meow ^5.0.0` dep.

## Revived (the easy path worked)

Running the committed `schism-stage0.wasm` under a **period-correct Node 12**
(`tools/node-v12.22.12`) with its original flags revives the full self-host
bootstrap — no Scheme and no codegen patches needed:

```
$ node12 --experimental-modules --experimental-wasm-anyref \
         --experimental-wasm-return-call run-tests.mjs
  ... stage0 succeeded / stage1 succeeded / stage2 succeeded   (per test)
```

`build.sh` runs this and asserts the self-host (stage0 → stage1 → stage2). The
whole test suite passes except `test/list-find.ss` (a pre-existing
compiler-correctness nit in the compiled output — not a bootstrap failure).

Still bitrotten separately: the standalone CLI `run-schism.mjs` uses an
extensionless ESM import that Node 12 also rejects; the bootstrap path
(`run-tests.mjs`) is the working entry point. A full modernization (run on
current V8) would still need the codegen patches (`ref.null` type immediate,
`anyref`→`externref`).

## Our changes

None yet. Revival is queued behind the compilers that build cleanly today.
