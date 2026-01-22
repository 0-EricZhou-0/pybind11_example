# Manage everything directly related to PyTorch in the CMake build system.

include_guard(GLOBAL)

find_package(Python3 COMPONENTS Interpreter REQUIRED)

# Function get_torch_version
# Arguments:
#   [Positional] [Return] OUTPUT_VAR: Name of the variable to store the Torch version.
function(get_torch_version OUTPUT_VAR)
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -c "import torch; print(torch.__version__)"
        OUTPUT_VARIABLE TORCH_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${OUTPUT_VAR} "${TORCH_VERSION}" PARENT_SCOPE)
endfunction()

# Function get_torch_include_path
# Arguments:
#   [Positional] [Return] OUTPUT_VAR: Name of the variable to store the Torch include paths.
function(get_torch_include_path OUTPUT_VAR)
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -c "import torch; from torch.utils.cpp_extension import include_paths; print(';'.join(include_paths()))"
        OUTPUT_VARIABLE TORCH_INCLUDE_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )
    set(${OUTPUT_VAR} "${TORCH_INCLUDE_PATH}" PARENT_SCOPE)
endfunction()
