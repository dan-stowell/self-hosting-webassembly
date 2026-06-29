# Wa (凹语言)

General-purpose, Go-like language **designed for WebAssembly**, compiler written
in Go.

| | |
|---|---|
| Tier / effort | 0 / 2 |
| Impl language | Go (stdlib only) |
| Backend | direct — own wasm backend, no LLVM |
| Status | ✅ **builds-to-wasm**, output verified byte-identical to native |
| Artifact | `dist/wa.wasm` (~31 MB; Go wasm binaries are large) |

## Self-host-to-wasm path

Wa is written in Go with **no external dependencies** and already ships a wasip1
entry point (`src/main_wasip1.go`). Go's standard toolchain cross-compiles the
entire compiler to a WASI module with no extra tooling:

```
GOOS=wasip1 GOARCH=wasm go build -o dist/wa.wasm .
```

`build.sh` does this (with `GOPROXY=off`, since it's offline-clean).

## Host deps

Go ≥ 1.17. Nothing else. A WASI runtime is needed only to *run* the result.

## Verified

The Wa compiler running as `wa.wasm` under wasm3 compiled `hello.wa` to a wasm
module that is **byte-identical** (same SHA-256) to the output of the native
`wa build`:

```
$ wasm3 --stack-size 8388608 dist/wa.wasm build -o h1.wasm hello.wa
$ cmp h1.wasm <(native wa build … hello.wa)   # identical
```

Gotcha: under **wasm3** the Go runtime needs a large interpreter stack —
`--stack-size 8388608` (8 MB). The 64 KB default overflows during real
compilation (the usage banner runs fine at default). Other runtimes
(wasmtime/Node) don't need the flag.

## Our changes

None yet — builds to wasm as-is.
