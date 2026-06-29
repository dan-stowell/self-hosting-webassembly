// A tiny embedder for the wasmi interpreter: load a wasm module from a file,
// instantiate it (no imports), call an exported function with i32 args, print
// the i32 result. Mirrors fizzy-run.c — lets us run wasmi AS wasm under toywasm
// without wasmi's WASI CLI (which needs nightly Rust).
use std::env;
use std::fs;
use wasmi::{Engine, Module, Store, Linker, Val};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: {} <module.wasm> <export> [i32-arg ...]", args[0]);
        std::process::exit(2);
    }
    let bytes = fs::read(&args[1])?;
    let engine = Engine::default();
    let module = Module::new(&engine, &bytes[..])?;
    let mut store = Store::new(&engine, ());
    let linker = <Linker<()>>::new(&engine);
    let instance = linker.instantiate_and_start(&mut store, &module)?;
    let func = instance.get_func(&store, &args[2])
        .ok_or_else(|| format!("no exported function '{}'", args[2]))?;

    let params: Vec<Val> = args[3..].iter()
        .map(|a| Val::I32(a.parse::<i32>().unwrap()))
        .collect();
    let mut results = vec![Val::I32(0)];
    func.call(&mut store, &params, &mut results)?;
    match results.get(0) {
        Some(Val::I32(v)) => println!("{} => i32:{}", args[2], v),
        Some(other)       => println!("{} => {:?}", args[2], other),
        None              => println!("{} => (void)", args[2]),
    }
    Ok(())
}
