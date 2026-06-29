/* Tiny embedder for WAMR's classic interpreter, using the wasm_export.h API.
 * Loads a wasm module, instantiates it, calls an exported function with i32
 * args, prints the i32 result. Lets us run WAMR (iwasm) AS wasm under toywasm
 * with libc-builtin (no WASI passthrough needed for compute modules).
 *
 * Usage: iwasm-run <module.wasm> <export> [i32-arg ...] */
#include "wasm_export.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <module.wasm> <export> [i32-arg ...]\n", argv[0]);
        return 2;
    }
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("open module"); return 1; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc(n);
    if (fread(buf, 1, n, f) != (size_t)n) { perror("read"); return 1; }
    fclose(f);

    RuntimeInitArgs init; memset(&init, 0, sizeof(init));
    init.mem_alloc_type = Alloc_With_System_Allocator;
    if (!wasm_runtime_full_init(&init)) { fprintf(stderr, "runtime init failed\n"); return 1; }

    char err[256];
    wasm_module_t module = wasm_runtime_load(buf, (uint32_t)n, err, sizeof(err));
    if (!module) { fprintf(stderr, "load: %s\n", err); return 1; }
    wasm_module_inst_t inst =
        wasm_runtime_instantiate(module, 65536, 65536, err, sizeof(err));
    if (!inst) { fprintf(stderr, "instantiate: %s\n", err); return 1; }
    wasm_exec_env_t env = wasm_runtime_create_exec_env(inst, 65536);
    wasm_function_inst_t func = wasm_runtime_lookup_function(inst, argv[2]);
    if (!func) { fprintf(stderr, "no export '%s'\n", argv[2]); return 1; }

    int nargs = argc - 3;
    uint32_t wargv[32];
    for (int i = 0; i < nargs && i < 32; i++)
        wargv[i] = (uint32_t)strtol(argv[3 + i], NULL, 0);

    if (!wasm_runtime_call_wasm(env, func, (uint32_t)nargs, wargv)) {
        fprintf(stderr, "trap: %s\n", wasm_runtime_get_exception(inst));
        return 1;
    }
    printf("%s => i32:%u\n", argv[2], wargv[0]);

    wasm_runtime_destroy_exec_env(env);
    wasm_runtime_deinstantiate(inst);
    wasm_runtime_unload(module);
    wasm_runtime_destroy();
    free(buf);
    return 0;
}
