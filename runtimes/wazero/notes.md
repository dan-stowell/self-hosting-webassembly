# wazero — a Go wasm runtime, compiled to wasm (phase 3)

| | |
|---|---|
| Upstream | tetratelabs/wazero @ `5f5f520`, Apache-2.0 |
| Lang | Go (pure Go, no cgo) |
| Compiled to wasm by | the Go toolchain itself (`GOOS=wasip1 GOARCH=wasm`) |
| Runs under | the tcc-built [toywasm](../toywasm/notes.md) |

The first non-C/C++ runtime in the floor. wazero is a pure-Go wasm runtime;
Go's own `wasip1/wasm` target compiles it to a `wasi_snapshot_preview1` module
that the tcc-built toywasm runs. `demo-in-wasm.sh`: `wat2wasm.wasm` (wabt, as
wasm) assembles a guest, then `wazero.wasm` runs that guest — wasm all the way
down across three ecosystems (C floor → Go runtime → guest).

## Why it works as wasm

wazero has two execution engines: an optimizing **compiler** that emits native
amd64/arm64 machine code, and a portable **interpreter**. The compiler can't
work *inside* wasm (no native codegen target), but wazero auto-detects that and
falls back to the interpreter, so `wazero.wasm` runs guests by interpreting
them. No patching needed — `go build` for wasip1 just works (one transitive
dep, `golang.org/x/sys`).

## The one gotcha: Go's wasip1 path mapping

Go's wasip1 runtime resolves a relative path against the WASI **preopen** whose
guest path is a prefix of it. toywasm's `--wasi-dir .` preopens with guest path
`.`, which doesn't prefix-match `hello.wasm`, so `open` returns `EBADF`
("Bad file number"). Map host `.` to guest `/` instead and use an absolute
guest path:

    toywasm --wasi --wasi-dir .::/ -- wazero.wasm run /hello.wasm

(wasi-libc tools like wat2wasm are more forgiving and accept `--wasi-dir .`
with a bare relative name; Go is stricter.)

## Size

~7.7 MB — Go statically links its runtime + GC into every binary. Big, but it
runs under the ~688 KB tcc-built toywasm without trouble.
