# Schism

The archetypal self-hosting compiler: a subset of R6RS Scheme → WebAssembly,
written in that same subset. Google project, **unmaintained since 2020**.

| | |
|---|---|
| Tier / effort | 0 / 4 |
| Impl language | Scheme |
| Backend | direct (its own wasm byte emitter) |
| Status | 🅥 vendored — **needs revival** (bitrotten 2019-era wasm + Node) |
| Artifact | `dist/schism.wasm` (target) |

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

## Revival paths

- **Easy (~effort 3):** run under a period-correct **Node ~12 / V8 ~7** where
  those flags + the 2019 encodings are valid; the committed stage0 snapshot then
  works without any Scheme. Sourcing that old Node is the blocker (the dev VM's
  GitHub-CDN/registry egress is firewalled).
- **Full (~effort 4–5):** patch the wasm emitter (`ref.null` type immediate,
  `anyref`→`externref`/GC), fix the Node flags + ESM specifiers, then
  re-bootstrap from source via Guile (`bootstrap-from-guile.sh`).

See `candidates.md` for the original assessment.

## Our changes

None yet. Revival is queued behind the compilers that build cleanly today.
