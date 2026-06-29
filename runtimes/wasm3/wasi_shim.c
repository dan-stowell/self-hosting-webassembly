/* wasi-libc lacks clock(); wasm3's m3_api_libc.c references it. Stub it
 * (CPU-time clock; 0 is harmless for running modules). */
#include <time.h>
clock_t clock(void) { return (clock_t)0; }
