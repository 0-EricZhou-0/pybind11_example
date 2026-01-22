cmake_minimum_required(VERSION 3.22)

# === CMake policy ===
# make CMAKE_INTERPROCEDURAL_OPTIMIZATION applies globally
set(CMAKE_POLICY_DEFAULT_CMP0069 NEW)

# === C/C++ standard ===
set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 20)

# === Project language specifications ===
# project(rag_sys LANGUAGES C CXX CUDA)
project(rag_sys LANGUAGES C CXX)

# === Essential utilities ===
include(cmake/utils.cmake)

# === CMake Options ===
# project switches
option(
    FORMATTING_ONLY
    "Only generate format related targets"
    OFF
)
option(
    GENERATE_GLOBAL_PY3_DEPENDENCY
    "Generate global Python3 package requirements, only asserted when excluding env-specific packages"
    OFF
)
option(
    GENERATE_ESSENTIAL_PY3_DEPENDENCY
    "Generate essential Python3 package requirements (i.e., excluding formatting, QoL, etc.)"
    OFF
)
# test configurations
set(
    GENERATE_TEST_PY3_DEPENDENCY "AUTO" CACHE STRING
    "Generate dependencies for running integration tests, AUTO for automatic selection based on build type"
)
assert_in_list(${GENERATE_TEST_PY3_DEPENDENCY} "AUTO;ON;OFF" "Invalid value for GENERATE_TEST_PY3_DEPENDENCY")
# pybind11 rich interface generation control
set(
    ENABLE_RICH_INTERFACE "AUTO" CACHE STRING
    "Enable rich pybind11 interface generation, AUTO for automatic selection based on build type"
)
# dependencies configuration
option(
    CUDA_TOOLKIT_VERSION
    "CUDA Toolkit version to use"
    "12.4"
)

# === CMake configurations ===
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_VERBOSE_MAKEFILE OFF)
# build type & optimization
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    # Debug build
    # resolve AUTO argument
    string(REPLACE "AUTO" "ON" GENERATE_TEST_PY3_DEPENDENCY_OPT ${GENERATE_TEST_PY3_DEPENDENCY})
    string(REPLACE "AUTO" "ON" ENABLE_RICH_INTERFACE_OPT ${ENABLE_RICH_INTERFACE})
else()
    # Release build
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
    # resolve AUTO argument
    string(REPLACE "AUTO" "OFF" GENERATE_TEST_PY3_DEPENDENCY_OPT ${GENERATE_TEST_PY3_DEPENDENCY})
    string(REPLACE "AUTO" "OFF" ENABLE_RICH_INTERFACE_OPT ${ENABLE_RICH_INTERFACE})
endif()

message(STATUS "Generate test dependencies: ${GENERATE_TEST_PY3_DEPENDENCY_OPT}")
message(STATUS "Enable rich interface: ${ENABLE_RICH_INTERFACE_OPT}")

# === Custom configurations ===
# Print all target building information formulated using cmake/build_helper.cmake:function(cxx_setup_target)
set(EXPORT_TARGET_CONFIG OFF)

# === Custom repository-wide variables ===
set(PYTHON_SRC_DIR ${CMAKE_SOURCE_DIR}/module)
set(RESOURCES_DIR ${CMAKE_SOURCE_DIR}/resources)

# === Create necessary directories ===

# === Include custom module subdirectories ===
# set(CMAKE_MODULE_PATH
#     ${CMAKE_SOURCE_DIR}/cmake/module
#     ${CMAKE_MODULE_PATH})

# === Include utilities ===
# python utilities
set(PY3_PKG_EXISTENCE_DIR ${CMAKE_BINARY_DIR}/py3_pkg_info)
set(PY3_PKGDEP_CHK_SCRIPT ${RESOURCES_DIR}/build_helper/py3_require_package.py)
set(PY3_EXEMOD_CHK_SCRIPT ${RESOURCES_DIR}/build_helper/py3_require_executable_module.py)
include(cmake/py3_utils.cmake)

# === Code Formatting configuration ===
# set(CLANG_FORMAT_DIR ${RESOURCES_DIR}/clang_format)
# set(BLACK_FORMAT_DIR ${RESOURCES_DIR}/black_format)
# include(cmake/clang_format.cmake)
# include(cmake/black_format.cmake)
# if(FORMATTING_ONLY)
#     message(STATUS "Only running clang-format, skipping other configurations.")
#     return()
# endif()

# === Include other predefined cmake files ===
# c++ build helper
include(cmake/build_helper.cmake)

# pybind11 utilities
set(LIBCLANG_FIND_VERSION_SCRIPT ${RESOURCES_DIR}/build_helper/get_libclang_version.py)
include(cmake/pybind11_utils.cmake)

# torch utilities
include(cmake/torch_utils.cmake)

# third-party library import
set(THIRD_PARTY_DIR ${CMAKE_SOURCE_DIR}/third_party)
include(cmake/third_party.cmake)

# === Custom project-wide variables ===
set(PYBIND11_MKDOC_DIR ${THIRD_PARTY_DIR}/pybind11_mkdoc)

# === Include subdirectories ===
add_subdirectory(csrc)

# === Conditional inclusion of subdirectories ===
if(GENERATE_TEST_PY3_DEPENDENCY_OPT)
    add_subdirectory(test)
endif()

# === Status report ===
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
