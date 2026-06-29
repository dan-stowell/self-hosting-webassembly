/* Minimal WAMR platform for wasm32-wasip1 (self-hosting iwasm to wasm).
 * Only the headers wasi-libc actually provides; no pthread/signal/mmap/sockets.
 * Single-threaded; HW bound check disabled (software bounds instead). */
#ifndef _PLATFORM_INTERNAL_H
#define _PLATFORM_INTERNAL_H

#include <inttypes.h>
#include <stdbool.h>
#include <assert.h>
#include <time.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdarg.h>
#include <ctype.h>
#include <limits.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BH_PLATFORM_WASI
#define BH_PLATFORM_WASI
#endif

#define BH_APPLET_PRESERVED_STACK_SIZE (32 * 1024)
#define BH_THREAD_DEFAULT_PRIORITY 0

/* Single-threaded: korp_* are trivial placeholders. */
typedef void *korp_tid;
typedef int korp_mutex;
typedef int korp_cond;
typedef void *korp_thread;
typedef int korp_sem;
typedef int korp_rwlock;
typedef struct { int fd; short events; short revents; } os_poll_file_handle;
typedef unsigned int os_nfds_t;
#define OS_THREAD_MUTEX_INITIALIZER 0

/* No real TLS without threads; globals are fine single-threaded. */
#define os_thread_local_attribute

#define bh_socket_t int

#define os_getpagesize() ((unsigned)65536)

typedef int os_file_handle;
typedef void *os_dir_stream;
typedef int os_raw_file_handle;
typedef struct timespec os_timespec;

static inline os_file_handle
os_get_invalid_handle(void)
{
    return -1;
}

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_INTERNAL_H */
