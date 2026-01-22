
include(${CMAKE_SOURCE_DIR}/cmake/py3_utils.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/pybind11_utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/module_defs.cmake)

# assumes variable PYTHON_SRC_DIR is already set to the path of the python source directory
assert_valid_path(PYTHON_SRC_DIR)
assert_valid_path(THIRD_PARTY_DIR)

if(NOT ENABLE_RICH_INTERFACE_OPT)
    set(ENABLE_RICH_INTERFACE_OPTSTR "NO_RICH_INTERFACE")
else()
    set(ENABLE_RICH_INTERFACE_OPTSTR)
endif()

# setup module
pybind11_setup_module(${PYBIND11_MODULE_NAME}
    COPTIONS -flto=auto -Wall -Wextra -Werror # treat every warning as an error
    TARGET PYBIND11_MODULE_TARGET
    SOURCES ${PYBIND11_MODULE_SOURCES}
    INCLUDES ${PYBIND11_MODULE_INCLUDES}
    DEPENDS ${PYBIND11_MODULE_DEPENDS}
    PYBIND11_INTERFACE_SOURCE ${PYBIND11_MODULE_INTERFACE_SOURCE}
    PYBIND11_MKDOC_MODULE_PATH ${PYBIND11_MKDOC_DIR}
    PYBIND11_GENERATED_INTERFACE_HEADER ${PYBIND11_GENERATED_INTERFACE_HEADER}
    ${ENABLE_RICH_INTERFACE_OPTSTR}
)
# avoid weird lto-wrapper warning on serial compilation
# Note: seems like -Wl,-flto=auto does not work, use direct -flto instead
target_link_options(${PYBIND11_MODULE_TARGET} PUBLIC -flto=auto)
# specify the module name for the python module through macro definition
target_compile_definitions(
    ${PYBIND11_MODULE_TARGET} PUBLIC PYBIND11_MODULE_NAME=${PYBIND11_MODULE_NAME}
)
