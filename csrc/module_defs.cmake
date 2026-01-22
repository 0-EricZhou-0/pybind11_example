# common module variables
# it sets the following variables for connivent target generation
# [PYBIND11_MODULE_SOURCES]:   all source files of the monitoring_sys
# [PYBIND11_MODULE_INCLUDES]:  all required include directories for the monitoring_sys
# [PROTO_PY_SOURCES]: generated protobuf python interfaces

# === module specific variables ===
set(PYBIND11_MODULE_NAME libmodule)

# === package requirements ===
# find_package(CUDAToolkit REQUIRED ${CUDA_TOOLKIT_VERSION} COMPONENTS cupti nvml)
find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

# # protobuf compilation
# file(GLOB PROTO_SOURCES ${RESOURCES_DIR}/proto/*.proto)
# proto_compile(PYBIND11_MODULE_PROTO_DEP
#     SOURCE_DIR   ${RESOURCES_DIR}/proto
#     CXX_DEST_DIR ${CMAKE_CURRENT_LIST_DIR}/generated/proto
#     PY_DEST_DIR  ${PYTHON_SRC_DIR}/proto
#     GEN_SOURCES  PROTO_SOURCES
#     SOURCES      ${PROTO_SOURCES}
# )

# # get generated cxx source files
# set(PROTO_CC_SOURCES ${PROTO_SOURCES})
# list(FILTER PROTO_CC_SOURCES INCLUDE REGEX "\\.cc$")
# # get generated python source files
# set(PROTO_PY_SOURCES ${PROTO_SOURCES})
# list(FILTER PROTO_PY_SOURCES INCLUDE REGEX "\\.py$")

# === determine [PYBIND11_MODULE_INTERFACE_SOURCE] ===
set(PYBIND11_MODULE_INTERFACE_SOURCE ${CMAKE_CURRENT_LIST_DIR}/src/pybind11_interface.cc)
set(PYBIND11_GENERATED_INTERFACE_HEADER ${CMAKE_CURRENT_LIST_DIR}/generated/interface/pybind11_defs.h)

# === determine [PYBIND11_MODULE_SOURCES] ===
set(PYBIND11_MODULE_SOURCES "")
# find all build  sources
file(GLOB PYBIND11_MODULE_CC_SOURCES ${CMAKE_CURRENT_LIST_DIR}/src/*.cc)
# aggregate them
# list(APPEND PYBIND11_MODULE_SOURCES ${PROTO_CC_SOURCES})
list(APPEND PYBIND11_MODULE_SOURCES ${PYBIND11_MODULE_CC_SOURCES})
# remove PYBIND11_MODULE_INTERFACE_SOURCE from list
list(REMOVE_ITEM PYBIND11_MODULE_SOURCES ${PYBIND11_MODULE_INTERFACE_SOURCE})


# === determine [PYBIND11_MODULE_DEPENDS] ===
# find all dependencies
set(PYBIND11_MODULE_DEPENDS
    # CUDA libraries
    # CUDA::cupti
    # CUDA::nvml
    # protobuf and absl libraries
    protobuf::libprotobuf
    absl::log
)


# === determine [PYBIND11_MODULE_INCLUDES] ===
# get_torch_include_path(TORCH_INCLUDES)
# find all includes
set(PYBIND11_MODULE_INCLUDES
    # project
    ${CMAKE_CURRENT_LIST_DIR}
    # python
    ${Python3_INCLUDE_DIRS}
    ${PYBIND11_INCLUDES}
    # torch
    # ${TORCH_INCLUDES}
    # cuda
    # ${CUDAToolkit_INCLUDE_DIRS}
    # protobuf
    ${Protobuf_INCLUDE_DIRS}
)
