(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (export "memory" (memory 0))
  (data (i32.const 8) "hello from wasm3, running inside tcc-built toywasm\n")
  (func $_start
    (i32.store (i32.const 0) (i32.const 8))
    (i32.store (i32.const 4) (i32.const 51))
    (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 64))))
  (export "_start" (func $_start)))
