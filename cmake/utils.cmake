# Helper functions & targets

include_guard(GLOBAL)

macro(assert condition message)
  if(NOT ${condition})
    message(FATAL_ERROR "Assertion failed: ${message}")
  endif()
endmacro()

# color printing support
if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColorReset       "${Esc}[m")
  set(ColorBold        "${Esc}[1m")
  set(ColorRed         "${Esc}[31m")
  set(ColorGreen       "${Esc}[32m")
  set(ColorYellow      "${Esc}[33m")
  set(ColorBlue        "${Esc}[34m")
  set(ColorMagenta     "${Esc}[35m")
  set(ColorCyan        "${Esc}[36m")
  set(ColorWhite       "${Esc}[37m")
  set(ColorBoldRed     "${Esc}[1;31m")
  set(ColorBoldGreen   "${Esc}[1;32m")
  set(ColorBoldYellow  "${Esc}[1;33m")
  set(ColorBoldBlue    "${Esc}[1;34m")
  set(ColorBoldMagenta "${Esc}[1;35m")
  set(ColorBoldCyan    "${Esc}[1;36m")
  set(ColorBoldWhite   "${Esc}[1;37m")
endif()

# Function pad_string
# Description:
#   Pad a string to a specified length with spaces
# Arguments:
#   [Positional] [Return] OUTPUT_VAR: Name of the variable to store the padded string
#   [Positional] STR: The string to pad
#   [Positional] LEN: The target length of the string
#   [Positional] LOCATION: Where to add padding: PRE (before), POST (after)
function(pad_string OUTPUT_VAR STR LEN LOCATION)
    string(LENGTH "${STR}" STRLEN)

    if(STRLEN LESS ${LEN})
        math(EXPR PADDING_LENGTH "${LEN} - ${STRLEN}")
        string(REPEAT " " ${PADDING_LENGTH} PADDING)
        if(${LOCATION} STREQUAL PRE)
            set(STR "${PADDING}${STR}")
        elseif(${LOCATION} STREQUAL POST)
            set(STR "${STR}${PADDING}")
        else()
            message(FATAL_ERROR "Invalid pad_string LOCATION")
        endif()
    endif()

    set(${OUTPUT_VAR} "${STR}" PARENT_SCOPE)
endfunction()


# Function assert_valid_path
# Description:
#   Asserts that a given path variable is defined and exists.
# Arguments:
#   [Positional] VAR_NAME: Name of the variable to check
function(assert_valid_path VAR_NAME)
    if(NOT DEFINED ${VAR_NAME})
        message(FATAL_ERROR "Path variable '${VAR_NAME}' is not set.")
    endif()

    # Use indirect expansion to get the value of the variable
    set(VAR_VALUE "${${VAR_NAME}}")

    if(NOT EXISTS "${VAR_VALUE}")
        message(FATAL_ERROR "Path '${VAR_VALUE}' (from variable '${VAR_NAME}') does not exist.")
    endif()
endfunction()


# Function generate_list_targets_target
# Description:
#   Generates a custom target 'list_targets' that lists all available build targets.
# Generated Target:
#   list_targets: Custom target that lists all available build targets.
function(generate_list_targets_target)
    set(LIST_TARGET_TARGET_NAME list_targets)
    if(NOT TARGET ${LIST_TARGET_TARGET_NAME})
        add_custom_target(${LIST_TARGET_TARGET_NAME}
            COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target help
            COMMENT "List all available targets"
        )
    endif()
endfunction()
# Call the function to generate the target at the end of everything
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL generate_list_targets_target)

# Function combine_path
# Description:
#   Combines multiple paths into a single string with a specified delimiter.
# Arguments:
#   DELIMITER: The delimiter to use when combining paths. Defaults to ":".
#   [MultiVal] PATHS: List of paths to combine.
#   [Return] OUTPUT_VAR: Name of the variable to store the combined path string.
function(combine_path)
    cmake_parse_arguments(ARG "" "DELIMITER;OUTPUT_VARIABLE" "PATHS" ${ARGN})
    # set to Unix style path delimiter by default
    if(NOT ARG_DELIMITER)
        set(ARG_DELIMITER ":")
    endif()

    string(JOIN ${ARG_DELIMITER} COMBINED_PATH ${ARG_PATHS})
    set(${ARG_OUTPUT_VARIABLE} "${COMBINED_PATH}" PARENT_SCOPE)
endfunction()

# Function assert_in_list
# Description:
#   Asserts that a given element is in a specified list.
# Arguments:
#   [Positional] ELEMENT: The element to check.
#   [Positional] TARGET_LIST: The list to check against.
#   [Positional] MESSAGE: The message to display if the assertion fails.
function(assert_in_list ELEMENT TARGET_LIST MESSAGE)
    if(NOT ${ELEMENT} IN_LIST TARGET_LIST)
        message(FATAL_ERROR "${MESSAGE}, '${ELEMENT}' is not in ${TARGET_LIST}.")
    endif()
endfunction()
