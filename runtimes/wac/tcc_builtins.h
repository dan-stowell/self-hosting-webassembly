/* Portable fallbacks for the bit-builtins tcc 0.9.27 lacks. wasm semantics:
 * i32/i64.clz/ctz of 0 == width, which these return — matching wa.c's needs. */
#ifndef TCC_BUILTINS_H
#define TCC_BUILTINS_H
static int __builtin_popcount(unsigned int x){int c=0;while(x){c+=x&1u;x>>=1;}return c;}
static int __builtin_popcountll(unsigned long long x){int c=0;while(x){c+=(int)(x&1ull);x>>=1;}return c;}
static int __builtin_clz(unsigned int x){int n=0;if(!x)return 32;while(!(x&0x80000000u)){n++;x<<=1;}return n;}
static int __builtin_ctz(unsigned int x){int n=0;if(!x)return 32;while(!(x&1u)){n++;x>>=1;}return n;}
static int __builtin_clzll(unsigned long long x){int n=0;if(!x)return 64;while(!(x&0x8000000000000000ull)){n++;x<<=1;}return n;}
static int __builtin_ctzll(unsigned long long x){int n=0;if(!x)return 64;while(!(x&1ull)){n++;x>>=1;}return n;}
#endif
