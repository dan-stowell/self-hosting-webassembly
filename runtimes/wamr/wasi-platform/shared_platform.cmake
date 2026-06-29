# Minimal WASI platform for WAMR (self-hosting iwasm to wasm32-wasip1).
set (PLATFORM_SHARED_DIR ${CMAKE_CURRENT_LIST_DIR})
add_definitions(-DBH_PLATFORM_WASI)
include_directories(${PLATFORM_SHARED_DIR})
include_directories(${PLATFORM_SHARED_DIR}/../include)
file (GLOB source_all ${PLATFORM_SHARED_DIR}/*.c)
set (PLATFORM_SHARED_SOURCE ${source_all})
file (GLOB header ${PLATFORM_SHARED_DIR}/../include/*.h)
LIST (APPEND RUNTIME_LIB_HEADER_LIST ${header})
