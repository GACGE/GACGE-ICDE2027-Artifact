include(FetchContent)
set(FETCHCONTENT_QUIET ON)

message(STATUS "Using External Project: Thrust")
set(FC_SOURCE_BASE "${PROJECT_DEPS_DIR}")
set(FC_BUILD_BASE "${PROJECT_DEPS_BUILD_DIR}")
set(FETCHCONTENT_BASE_DIR "${FC_BUILD_BASE}")

FetchContent_Declare(
    cccl
    GIT_REPOSITORY https://github.com/NVIDIA/cccl.git
    GIT_TAG        f67e324c2e9524a74151963e4a55132710ec6e13  # the commit the paper's builds used
    SOURCE_DIR     "${FC_SOURCE_BASE}/cccl-src"
    BINARY_DIR     "${FC_BUILD_BASE}/cccl-build"
    SUBBUILD_DIR   "${FC_BUILD_BASE}/cccl-subbuild"
    UPDATE_DISCONNECTED TRUE
)

FetchContent_GetProperties(cccl)
if(NOT cccl_POPULATED)
  FetchContent_MakeAvailable(
    cccl
  )
endif()
set(CCCL_INCLUDE_DIR "${cccl_SOURCE_DIR}")
