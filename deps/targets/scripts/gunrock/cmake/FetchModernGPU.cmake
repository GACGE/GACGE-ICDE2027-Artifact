include(FetchContent)
set(FETCHCONTENT_QUIET ON)

message(STATUS "Using External Project: ModernGPU")
set(FC_SOURCE_BASE "${PROJECT_DEPS_DIR}")
set(FC_BUILD_BASE "${PROJECT_DEPS_BUILD_DIR}")
set(FETCHCONTENT_BASE_DIR "${FC_BUILD_BASE}")

FetchContent_Declare(
    moderngpu
    URL            "${CMAKE_CURRENT_LIST_DIR}/../../../../vendor/moderngpu.tar.gz"  # the ModernGPU the paper's builds used
    URL_HASH       SHA256=cea85d0c553a155a9af59959c4842e38eca92ae4c4de61365e746a25c13be5dc
    SOURCE_DIR     "${FC_SOURCE_BASE}/moderngpu-src"
    BINARY_DIR     "${FC_BUILD_BASE}/moderngpu-build"
    SUBBUILD_DIR   "${FC_BUILD_BASE}/moderngpu-subbuild"
    UPDATE_DISCONNECTED TRUE
)

FetchContent_GetProperties(moderngpu)
if(NOT moderngpu_POPULATED)
  FetchContent_Populate(
    moderngpu
  )
endif()
set(MODERNGPU_INCLUDE_DIR "${moderngpu_SOURCE_DIR}/src")
