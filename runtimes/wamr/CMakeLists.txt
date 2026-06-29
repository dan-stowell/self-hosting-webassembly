# Minimal iwasm (classic interpreter + libc-builtin) for wasm32-wasip1.
cmake_minimum_required (VERSION 3.14)
project (iwasm C)

set (WAMR_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set (WAMR_BUILD_PLATFORM "wasi")
set (WAMR_BUILD_TARGET "X86_32")            # 32-bit ptr like wasm32; asm bypassed below
set (WAMR_BUILD_INVOKE_NATIVE_GENERAL 1)    # C native-call path, no per-arch asm
set (WAMR_BUILD_INTERP 1)
set (WAMR_BUILD_FAST_INTERP 0)              # classic interpreter
set (WAMR_BUILD_AOT 0)
set (WAMR_BUILD_JIT 0)
set (WAMR_BUILD_LIBC_BUILTIN 1)
set (WAMR_BUILD_LIBC_WASI 0)
set (WAMR_BUILD_MULTI_MODULE 0)
set (WAMR_BUILD_LIB_PTHREAD 0)
set (WAMR_BUILD_THREAD_MGR 0)
set (WAMR_BUILD_SIMD 0)
set (WAMR_DISABLE_HW_BOUND_CHECK 1)
set (WAMR_DISABLE_STACK_HW_BOUND_CHECK 1)
set (WAMR_DISABLE_WRITE_GS_BASE 1)
set (CMAKE_BUILD_TYPE Release)

include (${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake)
add_library (vmlib ${WAMR_RUNTIME_LIB_SOURCE})

add_executable (iwasm ${CMAKE_CURRENT_SOURCE_DIR}/iwasm-run.c)
target_include_directories (iwasm PRIVATE ${WAMR_ROOT_DIR}/core/iwasm/include)
target_link_libraries (iwasm vmlib)
set_target_properties (iwasm PROPERTIES OUTPUT_NAME iwasm-run)
