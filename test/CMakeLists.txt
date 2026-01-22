include(${CMAKE_SOURCE_DIR}/cmake/py3_utils.cmake)

add_py3_pkg_requirements(
    PACKAGES pytest pytest_harvest pandas
)