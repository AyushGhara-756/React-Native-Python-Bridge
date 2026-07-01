#include "PythonBridge.h"

#include <Python.h>
#include <cstdlib>
#include <cstdio>
#include <cstring>

// Store last error for recovery by ObjC module
static char g_lastError[4096] = {};
static char g_logPath[1024] = {};

const char *PythonBridge_getLastError() { return g_lastError; }

void PythonBridge_setLogPath(const char *path)
{
  if (path)
  {
    strncpy(g_logPath, path, sizeof(g_logPath) - 1);
  }
}

void PythonBridge_setError(const char* msg)
{
  strncpy(g_lastError, msg, sizeof(g_lastError) - 1);
}

static void writeLog(const char *msg)
{
  if (g_logPath[0])
  {
    FILE *f = fopen(g_logPath, "a");
    if (f)
    {
      fprintf(f, "%s\n", msg);
      fclose(f);
    }
  }
}

static void logError(const char *msg)
{
  char buf[1024];
  PyObject *exc = PyErr_GetRaisedException();
  if (exc)
  {
    PyObject *str = PyObject_Str(exc);
    const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
    snprintf(buf, sizeof(buf), "PythonBridge ERROR: %s -- %s", msg, errStr ? errStr : "?");
    Py_XDECREF(str);
    Py_DECREF(exc);
  }
  else
  {
    snprintf(buf, sizeof(buf), "PythonBridge ERROR: %s", msg);
  }
  strncpy(g_lastError, buf, sizeof(g_lastError) - 1);
  writeLog(buf);
}

namespace rnpythonbridge
{

  // RAII guard: acquire GIL on construction, release on destruction
  struct GILGuard {
    PyGILState_STATE state;
    GILGuard()  { state = PyGILState_Ensure(); }
    ~GILGuard() { PyGILState_Release(state); }
    GILGuard(const GILGuard&) = delete;
    GILGuard& operator=(const GILGuard&) = delete;
  };

  PythonBridge &PythonBridge::getInstance()
  {
    static PythonBridge instance;
    return instance;
  }

  bool PythonBridge::initialize(const char *pythonHome, const char *resourcePath)
  {
    if (initialized_)
    {
      return true;
    }

    Py_Initialize();
    if (!Py_IsInitialized())
    {
      logError("Py_Initialize failed");
      return false;
    }

    if (pythonHome)
    {
      PyObject *sysPath = PySys_GetObject("path");
      if (sysPath)
      {
        PyList_Insert(sysPath, 0, PyUnicode_DecodeFSDefault(pythonHome));
      }
    }
    if (resourcePath)
    {
      PyObject *sysPath = PySys_GetObject("path");
      if (sysPath)
      {
        PyList_Insert(sysPath, 0, PyUnicode_DecodeFSDefault(resourcePath));
      }
    }

    // Release GIL so other threads can acquire it via PyGILState_Ensure
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    PyEval_SaveThread();
    #pragma GCC diagnostic pop

    initialized_ = true;
    return true;
  }

  std::string PythonBridge::callPythonFunction(const char *moduleName, const char *functionName, const char *arg)
  {
    if (!initialized_)
    {
      return "Error: Python not initialized";
    }

    GILGuard gil;

    PyObject *pModule = PyImport_ImportModule(moduleName);
    if (!pModule)
    {
      PyObject *exc = PyErr_GetRaisedException();
      if (exc)
      {
        PyObject *str = PyObject_Str(exc);
        const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
        char buf[1024];
        snprintf(buf, sizeof(buf), "Error: Failed to import module: %s", errStr ? errStr : "unknown");
        Py_XDECREF(str);
        Py_DECREF(exc);
        return buf;
      }
      return "Error: Failed to import module";
    }

    PyObject *pFunc = PyObject_GetAttrString(pModule, functionName);
    if (!pFunc || !PyCallable_Check(pFunc))
    {
      PyObject *exc = PyErr_GetRaisedException();
      if (exc)
      {
        PyObject *str = PyObject_Str(exc);
        const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
        char buf[1024];
        snprintf(buf, sizeof(buf), "Error: Function not found: %s", errStr ? errStr : "unknown");
        Py_XDECREF(str);
        Py_DECREF(exc);
        Py_XDECREF(pFunc);
        Py_DECREF(pModule);
        return buf;
      }
      Py_XDECREF(pFunc);
      Py_DECREF(pModule);
      return "Error: Function not found or not callable";
    }

    PyObject *pResult;
    if (arg) {
      pResult = PyObject_CallFunction(pFunc, "s", arg);
    } else {
      pResult = PyObject_CallNoArgs(pFunc);
    }
    Py_DECREF(pFunc);

    if (!pResult)
    {
      PyObject *exc = PyErr_GetRaisedException();
      if (exc)
      {
        PyObject *str = PyObject_Str(exc);
        const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
        char buf[1024];
        snprintf(buf, sizeof(buf), "Error: Function call failed: %s", errStr ? errStr : "unknown");
        Py_XDECREF(str);
        Py_DECREF(exc);
        Py_DECREF(pModule);
        return buf;
      }
      Py_DECREF(pModule);
      return "Error: Function call failed";
    }

    const char *resultStr = PyUnicode_AsUTF8(pResult);
    std::string result = resultStr ? resultStr : "Error: Failed to convert result";

    Py_DECREF(pResult);
    Py_DECREF(pModule);

    return result;
  }

  std::string PythonBridge::callPythonFunction(const char *moduleName, const char *functionName, PyObject *args)
  {
    if (!initialized_)
    {
      return "Error: Python not initialized";
    }

    GILGuard gil;

    PyObject *pModule = PyImport_ImportModule(moduleName);
    if (!pModule)
    {
      PyObject *exc = PyErr_GetRaisedException();
      if (exc)
      {
        PyObject *str = PyObject_Str(exc);
        const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
        char buf[1024];
        snprintf(buf, sizeof(buf), "Error: Failed to import module: %s", errStr ? errStr : "unknown");
        Py_XDECREF(str);
        Py_DECREF(exc);
        return buf;
      }
      return "Error: Failed to import module";
    }

    PyObject *pFunc = PyObject_GetAttrString(pModule, functionName);
    if (!pFunc || !PyCallable_Check(pFunc))
    {
      PyObject *exc = PyErr_GetRaisedException();
      if (exc)
      {
        PyObject *str = PyObject_Str(exc);
        const char *errStr = str ? PyUnicode_AsUTF8(str) : "unknown";
        char buf[1024];
        snprintf(buf, sizeof(buf), "Error: Function not found: %s", errStr ? errStr : "unknown");
        Py_XDECREF(str);
        Py_DECREF(exc);
        Py_XDECREF(pFunc);
        Py_DECREF(pModule);
        return buf;
      }
      Py_XDECREF(pFunc);
      Py_DECREF(pModule);
      return "Error: Function not found or not callable";
    }

    PyObject *pResult = PyObject_CallObject(pFunc, args);
    Py_DECREF(pFunc);

    if (!pResult)
    {
      logError("callPythonFunction(PyObject*) failed");
      Py_DECREF(pModule);
      std::string err(g_lastError);
      return err;
    }

    const char *resultStr = PyUnicode_AsUTF8(pResult);
    std::string result = resultStr ? resultStr : "Error: Failed to convert result";

    Py_DECREF(pResult);
    Py_DECREF(pModule);

    return result;
  }

  void PythonBridge::finalize()
  {
    if (initialized_)
    {
      Py_Finalize();
      initialized_ = false;
    }
  }

}
