#include <pybind11/pybind11.h>
#include <pybind11/stl.h>

#ifdef PYBIND11_RICH_INTERFACE
#include "generated/interface/pybind11_defs.h"
#endif

#define STR_IMPL(x) #x
#define TO_STR(x)   STR_IMPL(x)

// Contains all the interface functions that should be registered with pybind11
// NOTE: namespace name does not need to be the same as the exported python module name, but rather
// the namespace used by the c++ library
namespace Module {
namespace Interface {

namespace Detail {

}  // namespace Detail

/**
 * Sample initialize function
 */
void initialize(std::string s, int arg) {
    printf(
        "Hello from the module %s with arg %s and %d.\n",
        (TO_STR(PYBIND11_MODULE_NAME)),
        s.c_str(),
        arg
    );
}

}  // namespace Interface
}  // namespace Module

// === Internal details BEGIN ===
// Expose a function to python using the same function name in c++
// NOTE: The function to be registered must resides in namespace Module::Interface
// TODO: Extract interface namespace into new macro to allow quick modification
#if defined(PYBIND11_RICH_INTERFACE) && defined(PYBIND11_ARG_INFO_GEN)
// Use a modified pybind11-mkdoc with arg info in macros
/*
 * FIXME: This does not work with overloaded functions because the macro `PYBIND11_ARG_TYPE(...)`
 * cannot resolve correctly, should call
 * `PYBIND11_ARG_TYPE(Module, Interface, func)(&Module::Interface::func)` on function
 * registration if the macro resolves correctly.
*/
#define PYBIND11_FANCY_BIND(m, func, ...)                       \
    m.def(                                                      \
        #func,                                                  \
        &Module::Interface::func,                         \
        pybind11::pos_only(), \
        PYBIND11_ARG_NAME(Module, Interface, func),       \
        PyDoc_STR(PYBIND11_DOC(Module, Interface, func)), \
        ##__VA_ARGS__)
// TODO: this still cannot resolve PYBIND11_ARG_NAME & PYBIND11_DOC ambiguity
// #define PYBIND11_FANCY_OVERLOAD_BIND(m, func, ...)
//     m.def(
//         #func,
//         pybind11::overload_cast<__VA_ARGS__>(&Module::Interface::func),
//         PYBIND11_ARG_NAME(Module, Interface, func),
//         PyDoc_STR(PYBIND11_DOC(Module, Interface, func))
//     )
#define PYBIND11_INTERFACE_DOCSTR(m) (m.doc() = PyDoc_STR(PYBIND11_DOC(PYBIND11, MODULE)))
#elif defined(PYBIND11_RICH_INTERFACE)
// Use a unmodified version of pybind11-mkdoc
// FIXME: This also does not work with overloaded functions
#define PYBIND11_FANCY_BIND(m, func, ...)               \
    m.def(                                              \
        #func,                                          \
        &Module::Interface::func,                         \
        PyDoc_STR(DOC(Module, Interface, func)),          \
        ##__VA_ARGS__                                   \
    )
#define PYBIND11_INTERFACE_DOCSTR(m) (m.doc() = PyDoc_STR(DOC(PYBIND11, MODULE)))
#else
// No pybind11-mkdoc is found
// Fallback to simple binding of function name only
#define PYBIND11_FANCY_BIND(m, func, ...) \
    m.def(#func, &Module::Interface::func, ##__VA_ARGS__)
#define PYBIND11_INTERFACE_DOCSTR(m) (m.doc() = "")
#endif

// Relies on external PYBIND11_MODULE_NAME passed to build system
#ifndef PYBIND11_MODULE_NAME
#error monitoring system name (macro PYBIND11_MODULE_NAME) is not set
#endif
// === Internal details END ===

/**
 * Sample pybind11 module definition
 */
PYBIND11_MODULE(PYBIND11_MODULE_NAME, m) {
    PYBIND11_INTERFACE_DOCSTR(m);
    // Do NOT change anything before this

    // === Interface functions ===
    PYBIND11_FANCY_BIND(m, initialize);
}
