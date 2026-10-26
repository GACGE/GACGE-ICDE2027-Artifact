cmake_minimum_required(VERSION 3.30)

project(graph-cpu-gpu-evaluation)

set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS TRUE CACHE BOOL "Suppress CMake developer warnings" FORCE)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib") # output directory of static libraries
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin") # output directory of shared libraries
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin") # output directory of executables

# This file lives in src/; the repository root holds deps/ (installed
# dependencies and their install scripts).
get_filename_component(REPO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

# ------------------------------------------------------------------
# Shared dependency setup
# ------------------------------------------------------------------
set(DEPS_ROOT_DIR "${REPO_ROOT_DIR}/deps")
set(DEPS_SCRIPTS_DIR "${DEPS_ROOT_DIR}/targets/scripts")

list(PREPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake"
    "${DEPS_SCRIPTS_DIR}/cmake/modules"
    "${DEPS_SCRIPTS_DIR}/cmake/scripts"
)

# ------------------------------------------------------------------
option(USE_CPU "Enable the CPU implementations (GAP, with XB-GAP)" ON)
option(USE_GPU "Enable the GPU implementations (Gunrock, with XB-Gunrock)" ON)
option(BUILD_APP_GAP "Build the GAP Benchmark Suite" ${USE_CPU})
option(BUILD_APP_GUNROCK "Build Gunrock" ${USE_GPU})

message(STATUS "USE_CPU=${USE_CPU}")
message(STATUS "USE_GPU=${USE_GPU}")

include(DetectNumericCudaArchitecture)
detect_numeric_cuda_architecture()
# Gunrock's CUDA sources need the language enabled at this level.
if(USE_GPU)
    enable_language(CUDA)
endif()

if(BUILD_APP_GAP)
    message(STATUS "Build Application GAP")
    add_subdirectory(gap "${CMAKE_BINARY_DIR}/gap")
endif ()

if(BUILD_APP_GUNROCK)
    message(STATUS "Build Application Gunrock")
    set(PROJECT_DEPS_DIR "${DEPS_ROOT_DIR}/gunrock")
    add_subdirectory(gunrock "${CMAKE_BINARY_DIR}/gunrock")
    # gunrock/loops (src/loops, header-only): the load-balancing schedules of
    # Osama et al., PPoPP 2023, used by the GACGE primitives (gacge_lb.hxx)
    target_include_directories(essentials INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/loops/include")
endif ()
