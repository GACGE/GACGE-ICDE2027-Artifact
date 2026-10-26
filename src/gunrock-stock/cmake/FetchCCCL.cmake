include(FetchContent)
set(FETCHCONTENT_QUIET ON)

message(STATUS "Cloning External Project: Thrust")
get_filename_component(FC_BASE "${PROJECT_SOURCE_DIR}/externals"
                REALPATH BASE_DIR "${CMAKE_BINARY_DIR}")
set(FETCHCONTENT_BASE_DIR ${FC_BASE})

FetchContent_Declare(
    cccl
    GIT_REPOSITORY https://github.com/NVIDIA/cccl.git
    GIT_TAG        45abc223418134fce41cc0fc6417c9819a957d16  # the commit the paper's builds used
)

FetchContent_GetProperties(cccl)
if(NOT cccl_POPULATED)
  FetchContent_MakeAvailable(
    cccl
  )
endif()
set(CCCL_INCLUDE_DIR "${cccl_SOURCE_DIR}")