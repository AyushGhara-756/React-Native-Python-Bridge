#pragma once

#include <Python.h>
#include <string>

extern "C" const char* PythonBridge_getLastError();
extern "C" void PythonBridge_setLogPath(const char* path);
extern "C" void PythonBridge_setError(const char* msg);

namespace rnpythonbridge {

class PythonBridge {
public:
  static PythonBridge& getInstance();
  bool initialize(const char* pythonHome, const char* resourcePath);
  bool initialize_v2(const char* pythonHome, const char* resourcePath);
  std::string callPythonFunction(const char* moduleName, const char* functionName, const char* arg = nullptr);
  std::string callPythonFunction(const char* moduleName, const char* functionName, PyObject* args);
  void finalize();

private:
  PythonBridge() = default;
  ~PythonBridge() = default;
  PythonBridge(const PythonBridge&) = delete;
  PythonBridge& operator=(const PythonBridge&) = delete;
  bool initialized_ = false;
};

}
