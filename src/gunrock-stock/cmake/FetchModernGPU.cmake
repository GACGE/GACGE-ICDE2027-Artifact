include(FetchContent)
set(FETCHCONTENT_QUIET ON)

message(STATUS "Cloning External Project: ModernGPU")
get_filename_component(FC_BASE "${PROJECT_SOURCE_DIR}/externals"
                REALPATH BASE_DIR "${CMAKE_BINARY_DIR}")
set(FETCHCONTENT_BASE_DIR ${FC_BASE})

FetchContent_Declare(
    moderngpu
    URL            "${CMAKE_CURRENT_LIST_DIR}/../../../deps/vendor/moderngpu.tar.gz"  # the ModernGPU the paper's builds used
    URL_HASH       SHA256=e05c6a85048a7c511de8a6056c304f3b5d5031baa4c01a8bb3d79831a016a09a
)

FetchContent_GetProperties(moderngpu)
if(NOT moderngpu_POPULATED)
  FetchContent_Populate(
    moderngpu
  )
endif()
set(MODERNGPU_INCLUDE_DIR "${moderngpu_SOURCE_DIR}/src")
