# RNPythonBridge

A React Native bridge that embeds **CPython 3.13** into iOS and Android apps, enabling JavaScript/TypeScript to call Python functions natively.

## Architecture

```
TypeScript        Native Bridge (JNI / ObjC++)     C++ Core          CPython
-----------       -------------------------------  --------------    ----------
App.tsx           PythonBridgeModule.kt / .mm      PythonBridge.cpp  Python 3.13
callPython()  ->  nativeCallPython()            -> callPythonFn() -> PyImport_ImportModule()
pythonBridge.ts   (type conversion)                (CPython API)     PyObject_CallFunction()
```

- **iOS**: ObjC++ native module → `PythonBridge.cpp` (static lib `libpython3.13.a`)
- **Android**: Kotlin module → JNI (`AndroidBridge.cpp`) → `PythonBridge2.cpp` (shared lib `libpython3.13.so`)

## Project Structure

```
RNPythonBridge/
  App.tsx                          # Demo app calling Python
  pythonBridge.ts                  # TypeScript bridge API
  cpp/
    PythonBridge.h / .cpp          # iOS C++ CPython wrapper (deprecated API)
    PythonBridge2.cpp              # Android C++ CPython wrapper (PyConfig API)
    HelloWorld.h / .cpp            # Sample native module
  ios/
    PythonBridgeModule.h / .mm     # iOS RN native module
    HelloWorldModule.h / .mm       # iOS sample module
    lib/libpython3.13.a            # Prebuilt CPython static lib
    include/                       # CPython headers (iOS)
  android/
    app/src/main/java/.../         # Kotlin RN module + package
    app/src/main/cpp/              # JNI bridge (AndroidBridge.cpp, CMakeLists.txt)
    app/src/main/assets/           # Python stdlib (extracted at runtime)
    app/jniLibs/                   # libpython3.13.so for each ABI
  python/
    hello.py                       # Demo Python module
    Python-3.13.14/                # CPython source tree
  scripts/
    build_python_ios.sh            # Cross-compile CPython for iOS
    build_python_android.sh        # Cross-compile CPython for Android
    download_python_android.sh     # Download prebuilt Android binaries
  RNPythonBridge.podspec           # CocoaPod spec
```

## Getting Started

### Prerequisites

- Node.js >= 22.11
- React Native CLI
- iOS: Xcode 15+, CocoaPods
- Android: Android Studio, NDK r27+, CMake 3.22+

### Install

```sh
npm install
cd ios && pod install && cd ..
```

### Run

```sh
npx react-native run-ios
npx react-native run-android
```

## TypeScript API

```ts
import { callPython, callPythonArgs } from './pythonBridge';

// Single argument
const result = callPython('hello', 'hello_world', 'ROAM');
// => { value: 'Hello World FROM Python ROAM', error: null }

// Multiple arguments
const result = callPythonArgs('hello', 'add', [10, 20, 30]);
// => { value: '60', error: null }
```

## Building CPython from Source

### iOS

```sh
./scripts/build_python_ios.sh
```

Builds `libpython3.13.a` targeting `arm64-apple-ios`. The following modules are disabled: fork, vfork, ctypes, bz2, lzma, dbm, uuid.

### Android

```sh
./scripts/build_python_android.sh
```

Cross-compiles for all four Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`). Disabled modules: fork, pipe, system, ctypes, lzma, bz2, dbm, uuid, ssl, hashlib, curses, subprocess.

## How It Works

1. **TypeScript** calls `NativeModules.RNPythonBridge.callPython(module, fn, arg)`
2. **iOS**: ObjC converts NSString/NSNumber/NSArray → PyObject, calls `PyObject_CallFunction`
3. **Android**: Kotlin converts ReadableArray/ReadableMap → Java ArrayList/HashMap, JNI bridge → C++ converts to PyObject
4. C++ core imports the Python module, calls the function, converts result to string via `PyUnicode_AsUTF8`

## Compatibility

| Platform | RN Version | Python | C++ Standard |
|----------|-----------|--------|-------------|
| iOS 15.1+ | 0.86.0 | 3.13 | C++20 |
| Android (API 24+) | 0.86.0 | 3.13 | C++17 |

## License

GPL-3.0
