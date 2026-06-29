/* Minimal WAMR platform implementation for wasm32-wasip1.
 * Single-threaded; mmap is malloc-backed; mprotect/caches are no-ops. Enough to
 * host the classic interpreter + libc-builtin (no AOT/JIT/threads/sockets). */
#include "platform_api_vmcore.h"
#include "platform_api_extension.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

/* ---- platform lifecycle ---- */
int bh_platform_init(void) { return 0; }
void bh_platform_destroy(void) {}

int os_thread_env_init(void) { return 0; }
void os_thread_env_destroy(void) {}
bool os_thread_env_inited(void) { return true; }

/* ---- memory ---- */
void *os_malloc(unsigned size) { return malloc(size); }
void *os_realloc(void *ptr, unsigned size) { return realloc(ptr, size); }
void os_free(void *ptr) { free(ptr); }

/* mmap: WAMR uses it to get (zeroed) linear-memory regions. Back it with an
 * over-aligned malloc so munmap is a plain free. We stash the base pointer just
 * before the aligned region so munmap/mremap can recover it. */
#define WASM_PAGE 65536u
void *os_mmap(void *hint, size_t size, int prot, int flags, os_file_handle file)
{
    (void)hint; (void)prot; (void)flags; (void)file;
    if (size == 0) size = 1;
    size_t total = size + WASM_PAGE + sizeof(void *);
    void *raw = malloc(total);
    if (!raw) return NULL;
    uintptr_t base = (uintptr_t)raw + sizeof(void *);
    uintptr_t aligned = (base + (WASM_PAGE - 1)) & ~(uintptr_t)(WASM_PAGE - 1);
    ((void **)aligned)[-1] = raw;
    memset((void *)aligned, 0, size);
    return (void *)aligned;
}
void os_munmap(void *addr, size_t size) { (void)size; if (addr) free(((void **)addr)[-1]); }
int os_mprotect(void *addr, size_t size, int prot) { (void)addr; (void)size; (void)prot; return 0; }
void *os_mremap(void *old_addr, size_t old_size, size_t new_size)
{
    return os_mremap_slow(old_addr, old_size, new_size);
}
void os_dcache_flush(void) {}
void os_icache_flush(void *start, size_t len) { (void)start; (void)len; }
void os_thread_jit_write_protect_np(bool enabled) { (void)enabled; }

/* ---- printing ---- */
int os_printf(const char *format, ...)
{
    va_list ap; va_start(ap, format);
    int n = vprintf(format, ap);
    va_end(ap);
    return n;
}
int os_vprintf(const char *format, va_list ap) { return vprintf(format, ap); }

/* ---- time ---- */
uint64 os_time_get_boot_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64)ts.tv_sec * 1000000 + (uint64)ts.tv_nsec / 1000;
}
uint64 os_time_thread_cputime_us(void) { return 0; }

/* ---- threads (single-threaded stubs) ---- */
korp_tid os_self_thread(void) { return (korp_tid)1; }
/* NULL boundary => WAMR skips native-stack-overflow checks. */
uint8 *os_thread_get_stack_boundary(void) { return NULL; }

int os_mutex_init(korp_mutex *m) { (void)m; return 0; }
int os_mutex_destroy(korp_mutex *m) { (void)m; return 0; }
int os_mutex_lock(korp_mutex *m) { (void)m; return 0; }
int os_mutex_unlock(korp_mutex *m) { (void)m; return 0; }
