# Manage third-party library imports in the CMake build system.
#
# Required variables:
# ::THIRD_PARTY_DIR::
#   Directory containing third-party libraries. Presumably a subdirectory of the project root.

include_guard(GLOBAL)

# assumes variable THIRD_PARTY_DIR is already set to the path of the third-party directory
assert_valid_path(THIRD_PARTY_DIR)

# === define submodule import rules ===
# pybind11 support
function(add_pybind11)
    set(PYBIND11_FOLDER ${THIRD_PARTY_DIR}/pybind11)
    # === import options ===
    # === import ===
    add_subdirectory(${PYBIND11_FOLDER} third_party/pybind11)
    # === src, include, depends, coptions, and loptions ===
    set(PYBIND11_INCLUDES ${PYBIND11_FOLDER}/include PARENT_SCOPE)
endfunction()

# === actually import the submodules ===
add_pybind11()

# NOTE: Refer to protobuf version naming here: https://protobuf.dev/support/version-support/
find_package(Protobuf 6 CONFIG QUIET)
