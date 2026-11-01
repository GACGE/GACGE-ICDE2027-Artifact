cmake_minimum_required(VERSION 3.16)

project(gap LANGUAGES CXX)

# The GAP Benchmark Suite (Beamer, Asanovic, Patterson, arXiv:1508.03619): the
# CPU baseline for BFS, SSSP, PageRank and TC. Its reference kernels come
# unmodified from src/gap/gapbs (sbeamer/gapbs 941462c plus our additions:
# xblossom.cc, X-Blossom as XB-GAP, and the reworked tc.cc) and are compiled as GAP's own Makefile does
# (g++ -std=c++11 -O3 -Wall -fopenmp, one translation unit per kernel), into
# build/gap/bin beside bin_to_gap, which writes GAP's serialized graphs from the
# GACGE binary CSR the other frameworks read. Nothing is built inside
# src/gap/gapbs.
set(GAP_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/gapbs")
if(NOT EXISTS "${GAP_SRC_DIR}/src/bfs.cc")
    message(FATAL_ERROR "GAP sources not found in ${GAP_SRC_DIR}")
endif()
find_program(GAP_CXX NAMES g++ REQUIRED)

set(GAP_BIN_DIR "${PROJECT_BINARY_DIR}/bin")
set(GAP_KERNELS bfs sssp pr pr_spmv tc xblossom)
set(GAP_CXX_FLAGS -std=c++11 -O3 -Wall -fopenmp)  # gapbs/Makefile: CXX_FLAGS + PAR_FLAG
file(GLOB GAP_HEADERS "${GAP_SRC_DIR}/src/*.h")
set(GAP_OUTPUTS)
foreach(k ${GAP_KERNELS})
    add_custom_command(
        OUTPUT "${GAP_BIN_DIR}/${k}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${GAP_BIN_DIR}"
        COMMAND "${GAP_CXX}" ${GAP_CXX_FLAGS} "${GAP_SRC_DIR}/src/${k}.cc" -o "${GAP_BIN_DIR}/${k}"
        DEPENDS "${GAP_SRC_DIR}/src/${k}.cc" ${GAP_HEADERS}
        COMMENT "Build GAP ${k}"
        VERBATIM)
    list(APPEND GAP_OUTPUTS "${GAP_BIN_DIR}/${k}")
endforeach()
add_custom_target(gapbs DEPENDS ${GAP_OUTPUTS})

# The same kernels with the barrier-wait instrumentation compiled in
# (-DGACGE_SYNC_STATS_BUILD=1, gapbs/src/gacge.h sync stats), into build/gap/bin-sync
# for the Sync profile legs only: not part of target gap, so the timed binaries
# never carry it. cmake --build build --target gap_sync
set(GAP_SYNC_BIN_DIR "${PROJECT_BINARY_DIR}/bin-sync")
set(GAP_SYNC_OUTPUTS)
foreach(k ${GAP_KERNELS})
    add_custom_command(
        OUTPUT "${GAP_SYNC_BIN_DIR}/${k}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${GAP_SYNC_BIN_DIR}"
        COMMAND "${GAP_CXX}" ${GAP_CXX_FLAGS} -DGACGE_SYNC_STATS_BUILD=1 "${GAP_SRC_DIR}/src/${k}.cc"
                -o "${GAP_SYNC_BIN_DIR}/${k}"
        DEPENDS "${GAP_SRC_DIR}/src/${k}.cc" ${GAP_HEADERS}
        COMMENT "Build GAP ${k} (sync stats)"
        VERBATIM)
    list(APPEND GAP_SYNC_OUTPUTS "${GAP_SYNC_BIN_DIR}/${k}")
endforeach()

add_executable(bin_to_gap bin_to_gap.cpp)
target_include_directories(bin_to_gap PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_features(bin_to_gap PRIVATE cxx_std_17)
set_target_properties(bin_to_gap PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${GAP_BIN_DIR}")

# gap_on_bin.sh runs the converter beside the kernel
add_custom_command(
    OUTPUT "${GAP_SYNC_BIN_DIR}/bin_to_gap"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${GAP_SYNC_BIN_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:bin_to_gap>" "${GAP_SYNC_BIN_DIR}/bin_to_gap"
    DEPENDS bin_to_gap
    VERBATIM)
add_custom_target(gap_sync DEPENDS ${GAP_SYNC_OUTPUTS} "${GAP_SYNC_BIN_DIR}/bin_to_gap")

# The original X-Blossom CPU implementation (Fan, Lee, Zhang, PVLDB 2025; std::thread), the reference XB-GAP is
# compared against (measure/xb-cpu XB-Original leg): src/xb-original, built with its own CMake flags
# (C++14, -O3, -pthread); only its graph reader and per-run report lines are ours (marked GACGE).
file(GLOB XB_ORIG_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../xb-original/*.cpp")
add_executable(xblossom_orig ${XB_ORIG_SOURCES})
target_include_directories(xblossom_orig PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_options(xblossom_orig PRIVATE -std=c++14 -O3 -pthread)
target_link_options(xblossom_orig PRIVATE -pthread)
set_target_properties(xblossom_orig PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${GAP_BIN_DIR}")

add_custom_target(gap DEPENDS gapbs bin_to_gap xblossom_orig)
