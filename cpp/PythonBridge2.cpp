#include "PythonBridge.h"
#include <android/log.h>
#include <cstdlib>
#include <cstdio>
#include <cerrno>

#define TAG "PythonBridge"

namespace rnpythonbridge {

bool PythonBridge::initialize_v2(const char *pythonHome, const char *resourcePath) {
    if (initialized_)
        return true;

    setenv("PYTHONMALLOC", "malloc", 1);

    PyConfig config;
    PyConfig_InitPythonConfig(&config);

    config.program_name = Py_DecodeLocale("python3.13", NULL);
    config.install_signal_handlers = 0;
    config.use_environment = 0;
    config.site_import = 0;

    if (pythonHome) {
        config.home = Py_DecodeLocale(pythonHome, NULL);
    }

    config.module_search_paths_set = 1;
    if (pythonHome) {
        wchar_t *path = Py_DecodeLocale(pythonHome, NULL);
        if (path) {
            PyWideStringList_Append(&config.module_search_paths, path);
            PyMem_RawFree(path);
        }
    }
    if (resourcePath) {
        wchar_t *path = Py_DecodeLocale(resourcePath, NULL);
        if (path) {
            PyWideStringList_Append(&config.module_search_paths, path);
            PyMem_RawFree(path);
        }
    }

    PyStatus status = Py_InitializeFromConfig(&config);
    PyConfig_Clear(&config);

    if (PyStatus_Exception(status)) {
        char buf[512];
        snprintf(buf, sizeof(buf), "Py_InitializeFromConfig failed: %s",
                 status.err_msg ? status.err_msg : "unknown");
        PythonBridge_setError(buf);
        return false;
    }

    if (resourcePath) {
        PyObject *sysPath = PySys_GetObject("path");
        if (sysPath) {
            PyList_Insert(sysPath, 0, PyUnicode_DecodeFSDefault(resourcePath));
        }
    }

    PyObject *sysPath = PySys_GetObject("path");
    if (sysPath) {
        PyObject *repr = PyObject_Repr(sysPath);
        if (repr) {
            const char *s = PyUnicode_AsUTF8(repr);
            __android_log_print(ANDROID_LOG_INFO, TAG, "sys.path = %s", s ? s : "?");
            Py_DECREF(repr);
        }
    }

    initialized_ = true;
    return true;
}

} // namespace
