// A tiny embedder for the fizzy wasm interpreter, using its C API. Loads a wasm
// module from a file, finds an exported function, executes it with i32 args,
// and prints the result. This is what lets us run fizzy AS wasm under toywasm
// without fizzy's normal CLI (fizzy-wasi), which depends on uvwasi/libuv — a
// native stack that won't compile to wasm. libfizzy's core has no such deps.
//
// Usage: fizzy-run <module.wasm> <export-name> [i32-arg ...]
#include <fizzy/fizzy.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <module.wasm> <export> [i32-arg ...]\n", argv[0]);
        return 2;
    }
    FILE* f = fopen(argv[1], "rb");
    if (!f) { perror("open module"); return 1; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t* buf = (uint8_t*)malloc(n);
    if (fread(buf, 1, n, f) != (size_t)n) { perror("read module"); return 1; }
    fclose(f);

    FizzyError err;
    const FizzyModule* mod = fizzy_parse(buf, (size_t)n, &err);
    if (!mod) { fprintf(stderr, "parse error: %s\n", err.message); return 1; }

    uint32_t idx;
    if (!fizzy_find_exported_function_index(mod, argv[2], &idx)) {
        fprintf(stderr, "no exported function '%s'\n", argv[2]);
        fizzy_free_module(mod);
        return 1;
    }

    FizzyInstance* inst = fizzy_instantiate(
        mod, NULL, 0, NULL, NULL, NULL, 0, FizzyMemoryPagesLimitDefault, &err);
    if (!inst) { fprintf(stderr, "instantiate error: %s\n", err.message); return 1; }

    int nargs = argc - 3;
    FizzyValue* args = nargs ? (FizzyValue*)malloc(sizeof(FizzyValue) * nargs) : NULL;
    for (int i = 0; i < nargs; i++)
        args[i].i32 = (uint32_t)strtol(argv[3 + i], NULL, 0);

    FizzyExecutionResult r = fizzy_execute(inst, idx, args, NULL);
    if (r.trapped) { fprintf(stderr, "trapped\n"); return 1; }
    if (r.has_value)
        printf("%s => i32:%u\n", argv[2], r.value.i32);
    else
        printf("%s => (void)\n", argv[2]);

    free(args);
    free(buf);
    fizzy_free_instance(inst);
    return 0;
}
