#!/bin/bash
set -euo pipefail

PYTHON_VERSION="3.13.14"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JNI_DIR="${PROJECT_DIR}/android/app/src/main/jniLibs"
INCLUDE_DIR="${PROJECT_DIR}/android/include"
ASSETS_DIR="${PROJECT_DIR}/android/app/src/main/assets"

PYTHON_SRC="${PROJECT_DIR}/python/Python-${PYTHON_VERSION}"
BUILD_SCRIPT="${SCRIPT_DIR}/build_python_android.sh"

ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

all_exist=true
for abi in "${ABIS[@]}"; do
    if [ ! -f "${JNI_DIR}/${abi}/libpython3.13.a" ]; then
        all_exist=false
        echo "Missing: ${JNI_DIR}/${abi}/libpython3.13.a"
    fi
done

if [ ! -f "${INCLUDE_DIR}/Python.h" ]; then
    all_exist=false
    echo "Missing: ${INCLUDE_DIR}/Python.h"
fi

if [ ! -d "${ASSETS_DIR}/python3.13" ]; then
    all_exist=false
    echo "Missing: ${ASSETS_DIR}/python3.13/ (stdlib)"
fi

if [ "$all_exist" = true ]; then
    echo "All Python Android binaries and headers are present."
    exit 0
fi

echo ""
echo "Python for Android is not fully set up."
echo ""
echo "Option 1: Build from source (requires Android NDK r27)"
echo "  Run: ${BUILD_SCRIPT}"
echo "  This will download CPython ${PYTHON_VERSION} source and cross-compile for all Android ABIs."
echo "  Estimated time: 10-30 minutes depending on machine speed."
echo ""
echo "Option 2: Manual setup"
echo "  Place prebuilt libpython3.13.a files in:"
for abi in "${ABIS[@]}"; do
    echo "    ${JNI_DIR}/${abi}/"
done
echo "  Place CPython headers (Python.h, pyconfig.h, etc.) in:"
echo "    ${INCLUDE_DIR}/"
echo "  Place Python stdlib in:"
echo "    ${ASSETS_DIR}/python3.13/"
echo ""
echo "Option 3: Use a stub for testing"
echo "  The app can't function without Python, but you can build the native"
echo "  module structure without linking Python by removing 'libpython' from"
echo "  CMakeLists.txt and #include <Python.h> references."
echo ""
echo "Recommended: Run the build script"
echo "  ${BUILD_SCRIPT}"
