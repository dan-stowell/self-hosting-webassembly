(module
  (import "wasi_unstable" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (export "memory" (memory 0))
  (data (i32.const 8) "hello from wax, a wasm interpreter built by tcc\n")
  (func $_start
    (i32.store (i32.const 0) (i32.const 8))    ;; iovec.buf = 8
    (i32.store (i32.const 4) (i32.const 48))   ;; iovec.len = 48
    (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 60))))
  (export "_start" (func $_start)))
