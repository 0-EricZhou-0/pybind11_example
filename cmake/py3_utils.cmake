# Manage Python-related dependencies in the CMake build system.

include_guard(GLOBAL)

# include standard cmake arguments handling
include(FindPackageHandleStandardArgs)

find_package(Python3 COMPONENTS Interpreter REQUIRED)

# check if python3 packaging module is available, bail if not found
execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import packaging.version"
    RESULT_VARIABLE PYTHON3_PACKAGING_MODULE_RESULT
)
if(NOT PYTHON3_PACKAGING_MODULE_RESULT EQUAL 0)
    message(FATAL_ERROR
        "Python3 packaging module is not found in the environment. "
        "To install packaging, run 'python3 -m pip install packaging'"
    )
endif()

# Function add_py3_pkg_dependencies
# Description:
#   Adds Python3 package dependencies to a CMake target.
# Arguments:
#   [Positional] TARGET: The CMake target that requires the Python3 packages.
#   [MultiVal] PKG_REQUIREMENTS:
#       List of Python3 package requirements in the format that follows the Python PEP 440 standard.
# Required variables:
#   PY3_PKG_EXISTENCE_DIR: Directory to store Python3 package existence check files. Presumably a
#                          subdirectory of the build directory.
#   PY3_PKGDEP_CHK_SCRIPT: Path to the Python3 script that checks for package requirements.
# Note:
#   See exactly how version specifiers work at python PEP (PEP 440):
#       https://peps.python.org/pep-0440/#version-specifiers
function(add_py3_pkg_dependencies target)
    cmake_parse_arguments(ARG "" "TARGET" "PKG_REQUIREMENTS;" ${ARGN})

    if(NOT DEFINED PY3_PKGDEP_CHK_SCRIPT OR NOT EXISTS ${PY3_PKGDEP_CHK_SCRIPT})
        message(FATAL_ERROR "Python3 package dependency check script not found")
    endif()

    if(NOT DEFINED PY3_PKG_EXISTENCE_DIR)
        message(FATAL_ERROR "Python3 package existence directory not defined")
    endif()

    # create the package existence check directory if it does not exist
    if(NOT EXISTS "${PY3_PKG_EXISTENCE_DIR}")
        file(MAKE_DIRECTORY ${PY3_PKG_EXISTENCE_DIR})
    endif()
    assert_valid_path(PY3_PKG_EXISTENCE_DIR)

    foreach(PKG_REQUIREMENT ${ARG_PKG_REQUIREMENTS})
        # convert the requirements string into a valid cmake target name
        string(REGEX MATCH
            "^([A-Za-z_][A-Za-z0-9_-]*)((~=|==|!=|<=|>=|<|>|===)(.*))?"
            PKG_REQUIREMENT_MATCH ${PKG_REQUIREMENT})
        set(PY3PKG_NAME "${CMAKE_MATCH_1}")
        set(PY3PKG_CONSTRAINT_FULL "${CMAKE_MATCH_2}")
        set(PY3PKG_CONSTRAINT "${CMAKE_MATCH_3}")
        set(PY3PKG_VERSION "${CMAKE_MATCH_4}")

        if(${PY3PKG_CONSTRAINT} STREQUAL "~=")
            set(PY3PKG_CONSTRAINT "CPEQ")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL "==")
            set(PY3PKG_CONSTRAINT "EXEQ")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL "!=")
            set(PY3PKG_CONSTRAINT "NTEQ")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL "<=")
            set(PY3PKG_CONSTRAINT "LTEQ")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL ">=")
            set(PY3PKG_CONSTRAINT "GTEQ")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL "<")
            set(PY3PKG_CONSTRAINT "LT")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL ">")
            set(PY3PKG_CONSTRAINT "GT")
        elseif(${PY3PKG_CONSTRAINT} STREQUAL "===")
            set(PY3PKG_CONSTRAINT "ABEQ")
        else()
            message(FATAL_ERROR "Unsupported package requirement constraint: ${PKG_REQUIREMENT}")
        endif()

        string(REPLACE "." "_" PY3PKG_VERSION "${PY3PKG_VERSION}")
        set(PKG_REQUIREMENT_TARGET_NAME "PY3PKG_REQ_${PY3PKG_NAME}_${PY3PKG_CONSTRAINT}_${PY3PKG_VERSION}")

        # create a custom target for each package requirement if not already defined
        if(NOT TARGET ${PKG_REQUIREMENT_TARGET_NAME})
            set(REQUIREMENT_FNAME
                "${PY3_PKG_EXISTENCE_DIR}/${PKG_REQUIREMENT_TARGET_NAME}.ok")

            add_custom_command(
                OUTPUT ${REQUIREMENT_FNAME}
                # suppress installed package version output
                COMMAND ${Python3_EXECUTABLE} ${PY3_PKGDEP_CHK_SCRIPT} ${PKG_REQUIREMENT} >/dev/null
                # if previous command failed (package not found), the touch command will never run
                COMMAND ${CMAKE_COMMAND} -E touch ${REQUIREMENT_FNAME}
                DEPENDS ${Python3_EXECUTABLE}
                VERBATIM
            )

            add_custom_target(
                ${PKG_REQUIREMENT_TARGET_NAME}
                DEPENDS ${REQUIREMENT_FNAME}
                COMMENT "Checking for required Python3 package: ${PKG_REQUIREMENT}"
            )
        endif()

        # add the package requirement target as a dependency to the specified target
        add_dependencies(${target} ${PKG_REQUIREMENT_TARGET_NAME})

        message(STATUS "Auto-requiring Python3 package: ${PKG_REQUIREMENT_MATCH} for target ${target}")
    endforeach()
endfunction()

# Global variable to store extra python3 package requirements, to be used by function
# add_py3_pkg_requirements and target generate_py3_requirements
set(EXTRA_PY3_PKG_REQUIREMENTS_VAR EXTRA_PY3_PKG_REQUIREMENTS)
set_property(GLOBAL PROPERTY ${EXTRA_PY3_PKG_REQUIREMENTS_VAR} "")

# Function add_py3_pkg_requirements
# Description:
#   Adds a global Python3 package requirement to the build system.
# Arguments:
#   PACKAGES: List of Python3 package requirements in the format that follows the PEP 440 standard.
#   [Option] OPTIONAL: If set, the package requirement is considered optional.
#   [Option] ENV_SPECIFIC: If set, the package requirement is not added to the global list of requirements.
# Note:
#   See exactly how version specifiers work at python PEP (PEP 440):
#       https://peps.python.org/pep-0440/#version-specifiers
function(add_py3_pkg_requirements)
    cmake_parse_arguments(ARG "OPTIONAL;ENV_SPECIFIC" "" "PACKAGES" ${ARGN})

    if(GENERATE_GLOBAL_PY3_DEPENDENCY AND ARG_ENV_SPECIFIC)
        message(STATUS
            "GENERATE_GLOBAL_PY3_DEPENDENCY set, global Python3 package requirement ${ARG_PACKAGES} is not added")
    elseif(GENERATE_ESSENTIAL_PY3_DEPENDENCY AND ARG_OPTIONAL)
        message(STATUS
            "GENERATE_ESSENTIAL_PY3_DEPENDENCY set, global Python3 package requirement: ${ARG_PACKAGES} is not added")
    else()
        set_property(GLOBAL APPEND PROPERTY ${EXTRA_PY3_PKG_REQUIREMENTS_VAR} "${ARG_PACKAGES}")
        message(STATUS "Adding global Python3 package requirement: ${ARG_PACKAGES}")
    endif()
endfunction()

# Function generate_py3_requirements
# Description:
#   Generates a python requirements file by combining all Python3 package requirements.
# Arguments:
#   INPUT_FILE: The input requirements file.
#   OUTPUT_FILE: The output requirements file to be generated.
# Targets Generated:
#   generate_py3_requirements: Custom target that generates the python requirements file.
function(generate_py3_requirements)
    cmake_parse_arguments(ARG "" "INPUT_FILE;OUTPUT_FILE;CACHE_DIR" "" ${ARGN})

    set(GEN_PY3_PKGREQ_TARGET generate_py3_requirements)
    find_program(PIP_COMPILE_EXECUTABLE pip-compile)
    if(NOT PIP_COMPILE_EXECUTABLE)
        message(STATUS
            "${ColorYellow}"
            "pip-compile not found, target ${GEN_PY3_PKGREQ_TARGET} will not be available. "
            "To install pip-compile, run `python3 -m pip install pip-tools`"
            "${ColorReset}"
        )
        return()
    endif()

    # create generated directory at input directory if it does not already exist
    if(ARG_CACHE_DIR STREQUAL "")
        cmake_path(APPEND GENERATED_DIR ${CMAKE_BINARY_DIR} "requirements")
    else()
        set(GENERATED_DIR ${ARG_CACHE_DIR})
    endif()
    if(NOT EXISTS ${GENERATED_DIR})
        file(MAKE_DIRECTORY ${GENERATED_DIR})
    endif()

    # write extra package requirements to a generated requirements file
    set(EXTRA_REQUIREMENTS_FILE "${GENERATED_DIR}/extra.in")
    set(NEW_EXTRA_REQUIREMENTS_FILE "${GENERATED_DIR}/extra.new.in")
    get_property(EXTRA_PY3_PKG_REQUIREMENTS GLOBAL PROPERTY ${EXTRA_PY3_PKG_REQUIREMENTS_VAR})
    set(EXTRA_PY3_PKG_REQUIREMENTS_CONTENTS "# === GENERATED BY CMAKE START ===\n")
    if(EXTRA_PY3_PKG_REQUIREMENTS)
        foreach(EXTRA_PY3_PKG_REQUIREMENT ${EXTRA_PY3_PKG_REQUIREMENTS})
            string(APPEND EXTRA_PY3_PKG_REQUIREMENTS_CONTENTS "${EXTRA_PY3_PKG_REQUIREMENT}\n")
        endforeach()
    endif()
    string(APPEND EXTRA_PY3_PKG_REQUIREMENTS_CONTENTS "# === GENERATED BY CMAKE END ===\n")
    file(WRITE ${NEW_EXTRA_REQUIREMENTS_FILE} "${EXTRA_PY3_PKG_REQUIREMENTS_CONTENTS}")

    # prevent cmake generate the target if cmake is run again but no changes are made
    if(EXISTS ${EXTRA_REQUIREMENTS_FILE})
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${NEW_EXTRA_REQUIREMENTS_FILE} ${EXTRA_REQUIREMENTS_FILE}
        )
    else()
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E copy
                    ${NEW_EXTRA_REQUIREMENTS_FILE} ${EXTRA_REQUIREMENTS_FILE}
        )
    endif()

    # merging all requirements, use relative path to avoid absolute path shown in generated file
    set(COMBINED_REQUIREMENTS_FILE "${GENERATED_DIR}/combined.in")
    cmake_path(RELATIVE_PATH COMBINED_REQUIREMENTS_FILE
        BASE_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE COMBINED_REQUIREMENTS_FILE_REL
    )
    cmake_path(RELATIVE_PATH ARG_OUTPUT_FILE
        BASE_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE OUTPUT_FILE_REL
    )

    add_custom_command(
        OUTPUT ${ARG_OUTPUT_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy ${EXTRA_REQUIREMENTS_FILE} ${COMBINED_REQUIREMENTS_FILE_REL}
        COMMAND ${CMAKE_COMMAND} -E cat ${ARG_INPUT_FILE} >> ${COMBINED_REQUIREMENTS_FILE_REL}
        COMMAND ${PIP_COMPILE_EXECUTABLE} ${COMBINED_REQUIREMENTS_FILE_REL}
                --output-file ${OUTPUT_FILE_REL}
                --strip-extras >/dev/null 2>&1 # silence output
        DEPENDS ${EXTRA_REQUIREMENTS_FILE} ${ARG_INPUT_FILE}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Generating Python3 requirements file via pip-compile using ${COMBINED_REQUIREMENTS_FILE_REL}, this may take a while"
    )

    add_custom_target(${GEN_PY3_PKGREQ_TARGET}
        DEPENDS ${ARG_OUTPUT_FILE}
        COMMENT "Generated Python3 requirements file to ${ARG_OUTPUT_FILE}"
    )

    message(STATUS "Python3 requirements file generation destination: ${ARG_OUTPUT_FILE}")
endfunction()

# Function find_py3_executable_module
# Description:
#   Checks if a Python module is executable (i.e., has a __main__.py file).
# Arguments:
#   [Positional] MODULE_NAME: The name of the Python module to check.
#   VERSION_REQUIREMENT: Optional version requirement string following PEP 440 format.
#   REASON_FAILURE_MESSAGE: Optional custom message to display if the module does not meet requirement.
#   [Option] REQUIRED: If set, the module is required and a fatal error is raised if not found.
#   [Option] QUIET: If set, status messages prints are suppressed.
#   [MultiVal] PYTHONPATH: List of paths to add to PYTHONPATH when checking for the module.
# Required variables:
#   PY3_EXEMOD_CHK_SCRIPT: Path to the Python3 script that checks for executable modules.
# Sets the following variables:
#   ${MODULE_NAME}_FOUND: True if the module is found, false otherwise.
#   ${MODULE_NAME}_MODULE: Module name if found.
#   ${MODULE_NAME}_VERSION: Version of the module if found.
# Note:
function(find_py3_executable_module module_name)
    cmake_parse_arguments(ARG "REQUIRED;QUIET" "MODULE_NAME;VERSION_REQUIREMENT;REASON_FAILURE_MESSAGE" "PYTHONPATH" ${ARGN})

    set(${module_name}_FOUND OFF)
    unset(${module_name}_MODULE)

    assert_valid_path(PY3_EXEMOD_CHK_SCRIPT)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${ARG_PYTHONPATH}
                ${Python3_EXECUTABLE} ${PY3_EXEMOD_CHK_SCRIPT} ${module_name}
        RESULT_VARIABLE PYTHON_EXEMOD_FOUND
        OUTPUT_QUIET
        ERROR_QUIET
    )

    # executable module found
    if(PYTHON_EXEMOD_FOUND EQUAL 0)
        # get exemod version
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${ARG_PYTHONPATH}
                    ${Python3_EXECUTABLE} ${PY3_PKGDEP_CHK_SCRIPT} "${module_name}${ARG_VERSION_REQUIREMENT}"
            OUTPUT_VARIABLE ${module_name}_VERSION
            RESULT_VARIABLE MODULE_VERSION_RESULT
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(MODULE_VERSION_RESULT EQUAL 0)
            set(${module_name}_FOUND ON)
            set(${module_name}_MODULE "${module_name}")
        endif()
    endif()

    # use standard args handling to set variables and print message
    if(ARG_REQUIRED OR NOT ARG_QUIET)
        # emit standard message, do not change any existing variables
        find_package_handle_standard_args(${module_name}
            REQUIRED_VARS ${module_name}_FOUND ${module_name}_MODULE ${module_name}_VERSION
            VERSION_VAR ${module_name}_VERSION
            REASON_FAILURE_MESSAGE "${ARG_REASON_FAILURE_MESSAGE}"
        )
    endif()

    if(${module_name}_FOUND)
        message(STATUS "Found Python3 executable module: ${${module_name}_MODULE} (version ${${module_name}_VERSION})")
        set(${module_name}_FOUND ${${module_name}_FOUND} PARENT_SCOPE)
        set(${module_name}_MODULE ${${module_name}_MODULE} PARENT_SCOPE)
        set(${module_name}_VERSION ${${module_name}_VERSION} PARENT_SCOPE)
    else()
        set(SEVERITY WARNING)
        if(ARG_REQUIRED)
            set(SEVERITY FATAL_ERROR)
        elseif(ARG_QUIET)
            set(SEVERITY STATUS)
        endif()
        message(${SEVERITY} "Python3 executable module: ${module_name} not found.")
    endif()
endfunction()

# call the function after everything to generate the requirements file
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL generate_py3_requirements
    INPUT_FILE ${RESOURCES_DIR}/requirements.in
    OUTPUT_FILE ${CMAKE_SOURCE_DIR}/requirements.txt
    CACHE_DIR ${CMAKE_BINARY_DIR}/py3_requirements
)
