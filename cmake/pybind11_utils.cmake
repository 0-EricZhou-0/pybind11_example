# Utility function to get libclang shared library version

include_guard(GLOBAL)
include(${CMAKE_SOURCE_DIR}/cmake/py3_utils.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/pybind11_utils.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/build_helper.cmake)

# global variables
set(VALID_MODULE_NAME_REGEX "^[a-zA-Z_][a-zA-Z0-9_]*$")
set(PYBIND11_MKDOC_MODULE_NAME pybind11_mkdoc)
set(PYBIND11_STUBGEN_PROGRAM_NAME pybind11-stubgen)


# === Configuration helpers ===
# Function get_libclang_sharedlib_version
# Description:
#   Get the version of the libclang shared library using an external Python script.
# Arguments:
#   [Positional] [Return] OUTPUT_VAR: Name of the variable to store the libclang version.
function(get_libclang_sharedlib_version OUTPUT_VAR)
    assert_valid_path(LIBCLANG_FIND_VERSION_SCRIPT)
    execute_process(
        COMMAND ${Python3_EXECUTABLE} ${LIBCLANG_FIND_VERSION_SCRIPT}
        OUTPUT_VARIABLE LIBCLANG_VERSION
        RESULT_VARIABLE LIBCLANG_VERSION_RESULT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(NOT LIBCLANG_VERSION_RESULT EQUAL 0)
        message(WARNING "Failed to get libclang version from shared library.")
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()

    set(${OUTPUT_VAR} "${LIBCLANG_VERSION}" PARENT_SCOPE)
endfunction()

# Conda environment does not provide Development.Module and corresponding cmake files to get
# ${Python3_EXTENSION_SUFFIX} is missing. Use python interpreter to get the suffix instead.
# REVIEW: Maybe find a way to do this logic to use Development.Module
if (NOT DEFINED Python3_EXTENSION_SUFFIX OR "${Python3_EXTENSION_SUFFIX}" STREQUAL "")
    message(STATUS "Python3_EXTENSION_SUFFIX is not found, check with interpreter")
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -c
            "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))"
        OUTPUT_VARIABLE Python3_EXTENSION_SUFFIX_RET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "Using Python3_EXTENSION_SUFFIX `${Python3_EXTENSION_SUFFIX_RET}`")
    set(Python3_EXTENSION_SUFFIX ${Python3_EXTENSION_SUFFIX_RET})
endif()


# Function pybind11_setup_module
# Description:
#   Setup a pybind11 module with given parameters.
# Arguments:
#   [Positional] module_name: Name of the pybind11 module to create.
#   [Return] [Optional] TARGET: Name of the output target variable to store the created module target
#   [Optional] PYBIND11_MKDOC_MODULE_PATH: Path to pybind11-mkdoc module if it is not already installed
#   PYBIND11_INTERFACE_SOURCE: Source file for the pybind11
#   PYBIND11_GENERATED_INTERFACE_HEADER:
#       Output header file for the generated rich interface, if not provided, system behave as if
#       option NO_RICH_INTERFACE is set
#   [MultiVal] SOURCES: Additional source files for the module
#   [MultiVal] INCLUDES: Additional include directories for the module
#   [MultiVal] DEPENDS: Additional dependencies for the module
#   [MultiVal] COPTIONS: Additional compile options for the module
#   [MultiVal] LOPTIONS: Additional link options for the module
#   [Option] NO_RICH_INTERFACE:
#       If set, the rich interface generation will be disabled and the module will only have basic
#       interface, should be asserted when in release build
# Generated Targets:
#   ${TARGET}: Target to create pybind11 module
#   ${TARGET}_pymod:
#       The target for create pybind11 module and position the output product to the python source
#       directory, depends on ${TARGET}
#   pybind11_mod_${TARGET}_gen_interface:
#       The generated rich interface target if rich interface generation is enabled
function(pybind11_setup_module module_name)
    cmake_parse_arguments(
        ARG
        "NO_RICH_INTERFACE"
        "MODULE_NAME;TARGET;PYBIND11_MKDOC_MODULE_PATH;PYBIND11_INTERFACE_SOURCE;PYBIND11_GENERATED_INTERFACE_HEADER"
        "SOURCES;INCLUDES;DEPENDS;COPTIONS;LOPTIONS"
        ${ARGN}
    )
    # a handy alias for module name
    set(PYBIND11_MODULE_NAME ${module_name})

    # remove the interface source from sources list (if exists) to avoid duplicate compilation, it
    # should be compiled as the main source file for pybind11 module
    list(REMOVE_ITEM ARG_SOURCES ${ARG_PYBIND11_INTERFACE_SOURCE})

    # === Setup module build ===
    # check for valid module name
    string(REGEX MATCH ${VALID_MODULE_NAME_REGEX} VALID_PYBIND11_MODULE_NAME ${PYBIND11_MODULE_NAME})
    if(NOT VALID_PYBIND11_MODULE_NAME)
        message(FATAL_ERROR
            "Invalid pybind11 module name ${PYBIND11_MODULE_NAME}. "
            "Should match regex ${VALID_MODULE_NAME_REGEX}). "
            "Refuse to generate python3 module ${PYBIND11_MODULE_NAME}."
        )
        return()
    endif()
    message(STATUS "Configuring pybind11 module ${PYBIND11_MODULE_NAME}")

    # input parameter validation
    if(ARG_PYBIND11_INTERFACE_SOURCE STREQUAL "")
        message(FATAL_ERROR "pybind11 interface source is not provided.")
    endif()

    # === Setup basic build ===
    # pybind11_add_module is analogous to cmake add_library calls
    pybind11_add_module(${PYBIND11_MODULE_NAME} ${ARG_PYBIND11_INTERFACE_SOURCE} ${ARG_SOURCES})
    cxx_setup_target(${PYBIND11_MODULE_NAME}
        INCLUDES "${ARG_INCLUDES}"
        DEPENDS  "${ARG_DEPENDS}"
        COPTIONS "${ARG_COPTIONS}"
        LOPTIONS "${ARG_LOPTIONS}"
    )
    # specify the module name for the python module through macro definition
    target_compile_definitions(
        ${PYBIND11_MODULE_NAME} PUBLIC PYBIND11_MODULE_NAME=${PYBIND11_MODULE_NAME}
    )

    # setup the CPython shared lib extension
    set_target_properties(${PYBIND11_MODULE_NAME} PROPERTIES
        PREFIX ""
        SUFFIX "${Python3_EXTENSION_SUFFIX}"
    )

    # === Generate rich interface ===
    if(ARG_NO_RICH_INTERFACE)
        message(STATUS "${ColorYellow}"
            "Disabling rich interface generation for pybind11 module ${PYBIND11_MODULE_NAME}"
            "${ColorReset}"
        )
    elseif(NOT ARG_PYBIND11_GENERATED_INTERFACE_HEADER OR ARG_PYBIND11_GENERATED_INTERFACE_HEADER STREQUAL "")
        message(STATUS "${ColorYellow}"
            "Generated interface header is not provided, disabling rich interface generation for pybind11 module ${PYBIND11_MODULE_NAME}."
            "${ColorReset}"
        )
    else()
        # check for libclang compatibility before aborting because of pybind11-mkdoc not found
        get_libclang_sharedlib_version(LIBCLANG_VERSION)
        # only match the major.minor version
        string(REGEX MATCH "^([0-9]+)\\.([0-9]+)" _ ${LIBCLANG_VERSION})
        set(LIBCLANG_VERSION_MAJOR "${CMAKE_MATCH_1}")
        set(LIBCLANG_VERSION_MINOR "${CMAKE_MATCH_2}")
        # set according to the part of version found
        if(NOT LIBCLANG_VERSION_MAJOR STREQUAL "" AND LIBCLANG_VERSION_MINOR STREQUAL "")
            set(LIBCLANG_VERSION "${LIBCLANG_VERSION_MAJOR}")
        elseif(NOT LIBCLANG_VERSION_MAJOR STREQUAL "" AND NOT LIBCLANG_VERSION_MINOR STREQUAL "")
            set(LIBCLANG_VERSION "${LIBCLANG_VERSION_MAJOR}.${LIBCLANG_VERSION_MINOR}")
        else()
            set(LIBCLANG_VERSION "")
        endif()

        # auto require libclang version if found
        if(NOT LIBCLANG_VERSION STREQUAL "")
            set(CLANG_REQUIREMENT "clang~=${LIBCLANG_VERSION}")
            add_py3_pkg_dependencies(${INTERFACE_GEN_TARGET}
                PKG_REQUIREMENTS "${CLANG_REQUIREMENT}"
            )
            add_py3_pkg_requirements(ENV_SPECIFIC PACKAGES "${CLANG_REQUIREMENT}")
        else()
            message(STATUS
                "${ColorYellow}"
                "Failed to auto infer libclang version and set requirement for ${PYBIND11_MODULE_NAME}."
                "Manual intervention may be required if pybind11-mkdoc fails."
                "${ColorReset}"
            )
        endif()

        # pybind11-stubgen, used to generate rich interface stubs
        find_program(PYBIND11_STUBGEN "${PYBIND11_STUBGEN_PROGRAM_NAME}")
        add_py3_pkg_requirements(ENV_SPECIFIC OPTIONAL PACKAGES "${PYBIND11_STUBGEN_PROGRAM_NAME}")
        if(NOT PYBIND11_STUBGEN)
            message(STATUS
                "${ColorYellow}"
                "${PYBIND11_STUBGEN_PROGRAM_NAME} not found, module ${PYBIND11_MODULE_NAME} will not have python stubs. "
                "To install ${PYBIND11_STUBGEN_PROGRAM_NAME}, run `python3 -m pip install ${PYBIND11_STUBGEN_PROGRAM_NAME}`."
                "${ColorReset}"
            )
        else()
            message(STATUS "Found ${PYBIND11_STUBGEN_PROGRAM_NAME} at ${PYBIND11_STUBGEN}")
        endif()

        # === Generate rich interface ===
        # enable stubgen with more information gathered from pybind11-mkdoc
        set(PYBIND11_INTERFACE_GEN_TARGET pybind11_mod_${PYBIND11_MODULE_NAME}_gen_interface)
        # target interface source file
        if(NOT ARG_PYBIND11_INTERFACE_SOURCE OR NOT EXISTS ${ARG_PYBIND11_INTERFACE_SOURCE})
            message(FATAL_ERROR "pybind11 source (${ARG_PYBIND11_INTERFACE_SOURCE}) is not provided or does not exist.")
        endif()
        # determine interface directory
        get_filename_component(PYBIND11_GENERATED_INTERFACE_DIR ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER} DIRECTORY)
        # determine pybind11-mkdoc module path
        set(PYBIND11_INTERFACE_GEN_ENABLED OFF)
        if(ARG_PYBIND11_MKDOC_MODULE_PATH)
            # a override path is provided
            if(ARG_PYBIND11_MKDOC_MODULE_PATH MATCHES ".*${PYBIND11_MKDOC_MODULE_NAME}")
                set(PYBIND11_MKDOC_MODULE_PATH ${ARG_PYBIND11_MKDOC_MODULE_PATH})
            else()
                set(PYBIND11_MKDOC_MODULE_PATH ${ARG_PYBIND11_MKDOC_MODULE_PATH}/${PYBIND11_MKDOC_MODULE_NAME})
            endif()
            # try find the module in the provided path
            find_py3_executable_module(${PYBIND11_MKDOC_MODULE_NAME}
                PYTHONPATH "${PYBIND11_MKDOC_MODULE_PATH}" QUIET
            )
            # refuse to generate interface if pybind11 mkdoc is not found
            if(${PYBIND11_MKDOC_MODULE_NAME}_FOUND)
                combine_path(
                    OUTPUT_VARIABLE PYTHONPATH
                    PATHS ${PYBIND11_MKDOC_MODULE_PATH} $ENV{PYTHONPATH}
                )
                # make interface generation a pre-build target
                add_custom_command(
                    OUTPUT ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}
                    COMMAND ${CMAKE_COMMAND} -E make_directory ${PYBIND11_GENERATED_INTERFACE_DIR}
                    # generate rich interface, redir stderr to devnull to avoid confusing fatal error
                    # message of cannot find include files when it tries to resolve all dependencies that
                    # are not actually needed
                    COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PYTHONPATH}
                            ${Python3_EXECUTABLE} -m ${PYBIND11_MKDOC_MODULE_NAME}
                                                  -o ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}
                                                  ${ARG_PYBIND11_INTERFACE_SOURCE} 2>/dev/null
                    DEPENDS ${ARG_PYBIND11_INTERFACE_SOURCE}
                    COMMENT "Pybind11 mkdoc generating rich interface for ${PYBIND11_MODULE_NAME} at ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}"
                )
                set(PYBIND11_INTERFACE_GEN_ENABLED ON)
            else()
                message(STATUS
                    "${ColorYellow}"
                    "Cannot find or initialize ${PYBIND11_MKDOC_MODULE_NAME}, "
                    "refuse to generate rich interface for pybind11 module ${PYBIND11_MODULE_NAME}."
                    "${ColorReset}"
                )
            endif()
        else()
            # a override path is not provided, check for system installation
            find_py3_executable_module(${PYBIND11_MKDOC_MODULE_NAME}
                PYTHONPATH "$ENV{PYTHONPATH}" QUIET
            )
            if(${PYBIND11_MKDOC_MODULE_NAME}_FOUND)
                # make interface generation a pre-build target
                add_custom_command(
                    OUTPUT ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}
                    COMMAND ${CMAKE_COMMAND} -E make_directory ${PYBIND11_GENERATED_INTERFACE_DIR}
                    # generate rich interface, redir stderr to devnull to avoid confusing fatal error
                    # message of cannot find include files when it tries to resolve all dependencies that
                    # are not actually needed
                    COMMAND ${Python3_EXECUTABLE} -m ${PYBIND11_MKDOC_MODULE_NAME}
                                                  -o ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}
                                                  ${INTERFACE_SOURCES} 2>/dev/null
                    DEPENDS ${ARG_PYBIND11_INTERFACE_SOURCE}
                )
                set(PYBIND11_INTERFACE_GEN_ENABLED ON)
            else()
                message(STATUS
                    "${ColorYellow}"
                    "Cannot find or initialize system installation of ${PYBIND11_MKDOC_MODULE_NAME}, "
                    "refuse to generate rich interface target ${PYBIND11_INTERFACE_GEN_TARGET}."
                    "${ColorReset}"
                )
            endif()
        endif()

        # make generate interface target if enabled and all dependencies are met
        if(PYBIND11_INTERFACE_GEN_ENABLED)
            add_custom_target(${PYBIND11_INTERFACE_GEN_TARGET}
                # make sure the interface header is generated before building the target
                DEPENDS ${ARG_PYBIND11_GENERATED_INTERFACE_HEADER}
                COMMENT "Generate rich interface for ${PYBIND11_MODULE_NAME}"
            )
            # enable rich interface by specifying macro so c++ program knows it
            target_compile_definitions(${PYBIND11_MODULE_NAME} PUBLIC PYBIND11_RICH_INTERFACE)
            add_dependencies(${PYBIND11_MODULE_NAME} ${PYBIND11_INTERFACE_GEN_TARGET})
        endif()
    endif()

    # === Install the module ===
    # symlink the library to ${PYTHON_SRC_DIR}/${PYBIND11_MODULE_NAME} folder and generate stub for
    # the lib after build complete
    set(PYBIND11_MODULE_DESTINATION ${PYTHON_SRC_DIR}/${PYBIND11_MODULE_NAME})
    if(NOT PYBIND11_STUBGEN)
        add_custom_target(${PYBIND11_MODULE_NAME}_pymod
            # symlink the shared lib to target directory
            COMMAND ${CMAKE_COMMAND} -E make_directory ${PYBIND11_MODULE_DESTINATION}
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                        $<TARGET_FILE:${PYBIND11_MODULE_NAME}>
                        ${PYBIND11_MODULE_DESTINATION}/$<TARGET_FILE_NAME:${PYBIND11_MODULE_NAME}>
            COMMAND ${CMAKE_COMMAND} -E echo "from .${PYBIND11_MODULE_NAME} import *" > "${PYBIND11_MODULE_DESTINATION}/__init__.py"
            COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --cyan
                        "Symlink-ed lib in ${PYBIND11_MODULE_DESTINATION}/$<TARGET_FILE_NAME:${PYBIND11_MODULE_NAME}>"

            WORKING_DIRECTORY $<TARGET_FILE_DIR:${PYBIND11_MODULE_NAME}>
            DEPENDS ${PYBIND11_MODULE_NAME}
            COMMENT "Build pybind11 module ${PYBIND11_MODULE_NAME} and position output product to ${PYBIND11_MODULE_DESTINATION}"
            VERBATIM
        )
    else()
        add_custom_target(${PYBIND11_MODULE_NAME}_pymod
            # symlink the shared lib to target directory
            COMMAND ${CMAKE_COMMAND} -E make_directory ${PYBIND11_MODULE_DESTINATION}
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                        $<TARGET_FILE:${PYBIND11_MODULE_NAME}>
                        ${PYBIND11_MODULE_DESTINATION}/$<TARGET_FILE_NAME:${PYBIND11_MODULE_NAME}>
            COMMAND ${CMAKE_COMMAND} -E echo "from .${PYBIND11_MODULE_NAME} import *" > "${PYBIND11_MODULE_DESTINATION}/__init__.py"
            COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --cyan
                        "Symlink-ed lib in ${PYBIND11_MODULE_DESTINATION}/$<TARGET_FILE_NAME:${PYBIND11_MODULE_NAME}>"
            # generate stub using pybind11-stubgen
            COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${PYBIND11_MODULE_DESTINATION}
                    ${PYBIND11_STUBGEN} ${PYBIND11_MODULE_NAME} -o "${PYBIND11_MODULE_DESTINATION}"
            COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --cyan "Stub generated in ${PYBIND11_MODULE_DESTINATION}"

            WORKING_DIRECTORY $<TARGET_FILE_DIR:${PYBIND11_MODULE_NAME}>
            DEPENDS ${PYBIND11_MODULE_NAME}
            COMMENT "Build pybind11 module ${PYBIND11_MODULE_NAME} and position output product with stub to ${PYBIND11_MODULE_DESTINATION}"
            VERBATIM
        )
    endif()

    # export target back to caller scope
    set(${ARG_TARGET} "${PYBIND11_MODULE_NAME}" PARENT_SCOPE)
endfunction()
