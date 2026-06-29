// Tiny embedder for wasmtime's Pulley interpreter, built for wasm32-wasip1.
// Loads a module, calls an export with i32 args, prints the i32 result.
//
// Because wasip1 is an "unsupported OS" to wasmtime's sys layer, we enable the
// `custom-virtual-memory` feature and supply the platform hooks below. Pulley
// does explicit bounds checks (no hardware traps), so mmap can be plain malloc,
// mprotect a no-op, and there are no signal/sync hooks to provide.
use std::{env, fs};
use wasmtime::{Engine, Module, Store, Instance, Val, Config};

// ---- wasmtime custom-platform hooks (see runtime/vm/sys/custom/capi.rs) ----
mod platform {
    use core::ffi::c_void;
    extern "C" {
        fn malloc(n: usize) -> *mut c_void;
        fn free(p: *mut c_void);
        fn memset(p: *mut c_void, v: i32, n: usize) -> *mut c_void;
    }
    const PAGE: usize = 65536;

    // malloc-backed mmap: over-align to 64K, stash the raw base just before it.
    #[no_mangle]
    pub extern "C" fn wasmtime_mmap_new(size: usize, _prot: u32, ret: &mut *mut u8) -> i32 {
        let size = if size == 0 { 1 } else { size };
        let total = size + PAGE + core::mem::size_of::<*mut u8>();
        let raw = unsafe { malloc(total) } as usize;
        if raw == 0 { return -1; }
        let base = raw + core::mem::size_of::<*mut u8>();
        let aligned = (base + (PAGE - 1)) & !(PAGE - 1);
        unsafe {
            *((aligned as *mut *mut u8).offset(-1)) = raw as *mut u8;
            memset(aligned as *mut c_void, 0, size);
        }
        *ret = aligned as *mut u8;
        0
    }
    #[no_mangle]
    pub extern "C" fn wasmtime_mmap_remap(_addr: *mut u8, _size: usize, _prot: u32) -> i32 { -1 }
    #[no_mangle]
    pub extern "C" fn wasmtime_munmap(ptr: *mut u8, _size: usize) -> i32 {
        if !ptr.is_null() { unsafe { free(*((ptr as *mut *mut u8).offset(-1)) as *mut c_void); } }
        0
    }
    #[no_mangle]
    pub extern "C" fn wasmtime_mprotect(_ptr: *mut u8, _size: usize, _prot: u32) -> i32 { 0 }
    #[no_mangle]
    pub extern "C" fn wasmtime_page_size() -> usize { PAGE }

    // No CoW image support: store NULL (not a failure) so wasmtime copies instead.
    #[no_mangle]
    pub extern "C" fn wasmtime_memory_image_new(_ptr: *const u8, _len: usize, ret: &mut *mut c_void) -> i32 {
        *ret = core::ptr::null_mut(); 0
    }
    #[no_mangle]
    pub extern "C" fn wasmtime_memory_image_map_at(_image: *mut c_void, _addr: *mut u8, _len: usize) -> i32 { -1 }
    #[no_mangle]
    pub extern "C" fn wasmtime_memory_image_free(_image: *mut c_void) {}

    // Single-threaded TLS: a tiny static slot array.
    static mut TLS: [*mut u8; 2] = [core::ptr::null_mut(); 2];
    #[no_mangle]
    pub extern "C" fn wasmtime_tls_get(slot: usize) -> *mut u8 { unsafe { TLS[slot] } }
    #[no_mangle]
    pub extern "C" fn wasmtime_tls_set(slot: usize, ptr: *mut u8) { unsafe { TLS[slot] = ptr; } }
}

fn main() -> wasmtime::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: {} <module.wasm> <export> [i32-arg ...]", args[0]);
        std::process::exit(2);
    }
    let bytes = fs::read(&args[1])?;

    let mut config = Config::new();
    // No guard pages / signal traps: Pulley bounds-checks explicitly.
    config.signals_based_traps(false);
    config.memory_reservation(0);
    config.memory_guard_size(0);
    config.memory_reservation_for_growth(0);
    config.memory_init_cow(false);
    let engine = Engine::new(&config)?;

    let module = Module::new(&engine, &bytes)?;
    let mut store = Store::new(&engine, ());
    let instance = Instance::new(&mut store, &module, &[])?;
    let func = instance.get_func(&mut store, &args[2])
        .ok_or_else(|| wasmtime::Error::msg("no such export"))?;
    let params: Vec<Val> = args[3..].iter().map(|a| Val::I32(a.parse().unwrap())).collect();
    let mut results = [Val::I32(0)];
    func.call(&mut store, &params, &mut results)?;
    match results[0] {
        Val::I32(v) => println!("{} => i32:{}", args[2], v),
        ref o => println!("{} => {:?}", args[2], o),
    }
    Ok(())
}
