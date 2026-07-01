#!/bin/bash
set -euo pipefail

PYTHON_VERSION="3.13.14"
PYTHON_DIR="Python-${PYTHON_VERSION}"
PYTHON_TAR="${PYTHON_DIR}.tar.xz"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TAR}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON_SRC="${PROJECT_DIR}/python/${PYTHON_DIR}"
BUILD_DIR="${PROJECT_DIR}/python/build_ios"
OUTPUT_DIR="${BUILD_DIR}/output"

SDK_NAME="iphoneos"
SDK_PATH=$(xcrun --sdk ${SDK_NAME} --show-sdk-path)
CC=$(xcrun --sdk ${SDK_NAME} --find clang)
CXX=$(xcrun --sdk ${SDK_NAME} --find clang++)
CPP="${CC} -E"
AR=$(xcrun --sdk ${SDK_NAME} --find ar)
ARCH="arm64"
MIN_IOS="15.1"
HOST_ARCH=$(uname -m)

CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -miphoneos-version-min=${MIN_IOS} -D_FORTIFY_SOURCE=0"
CXXFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -miphoneos-version-min=${MIN_IOS} -D_FORTIFY_SOURCE=0"
LDFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} -miphoneos-version-min=${MIN_IOS}"

export CC CXX CPP AR
export CFLAGS CXXFLAGS LDFLAGS

mkdir -p "${BUILD_DIR}"

# Download CPython source if not present
if [ ! -d "${PYTHON_SRC}" ]; then
  if [ ! -f "${BUILD_DIR}/${PYTHON_TAR}" ]; then
    echo "=== Downloading CPython ${PYTHON_VERSION} ==="
    curl -L --fail "${PYTHON_URL}" -o "${BUILD_DIR}/${PYTHON_TAR}"
  fi
  echo "=== Extracting ==="
  tar xf "${BUILD_DIR}/${PYTHON_TAR}" -C "${PROJECT_DIR}/python/"
fi

echo "=== Cleaning previous build ==="
cd "${PYTHON_SRC}"
make distclean 2>/dev/null || true

echo "=== Configuring CPython for iOS arm64 ==="
./configure \
  --host=arm64-apple-ios \
  --build=${HOST_ARCH}-apple-darwin \
  --disable-shared \
  --enable-framework \
  --without-ensurepip \
  --disable-test-modules \
  --with-build-python=/opt/homebrew/bin/python3.13 \
  --with-pkg-config=no \
  ac_cv_file__dev_ptmx=no \
  ac_cv_file__dev_ptc=no \
  ac_cv_func_fork=no \
  ac_cv_func_fork_works=no \
  ac_cv_func_forkpty=no \
  ac_cv_func_vfork=no \
  ac_cv_func_system=no \
  ac_cv_func_pipe=no \
  ac_cv_func_pipe2=no \
  ac_cv_func_dlopen=yes \
  ac_cv_func_dlclose=yes \
  ac_cv_func_dlsym=yes \
  ac_cv_have_long_long_format=yes \
  ac_cv_type_uid_t=yes \
  ac_cv_type_gid_t=yes \
  ac_cv_type_pid_t=yes \
  ac_cv_type_mode_t=yes \
  ac_cv_type_off_t=yes \
  ac_cv_type_size_t=yes \
  ac_cv_type_ssize_t=yes \
  ac_cv_type_time_t=yes \
  ac_cv_type_clock_t=yes \
  ac_cv_sizeof_int=4 \
  ac_cv_sizeof_long=8 \
  ac_cv_sizeof_long_long=8 \
  ac_cv_sizeof_void_p=8 \
  ac_cv_sizeof_short=2 \
  ac_cv_sizeof_float=4 \
  ac_cv_sizeof_double=8 \
  ac_cv_sizeof_size_t=8 \
  ac_cv_sizeof_fpos_t=8 \
  ac_cv_sizeof__Bool=1 \
  ac_cv_alignof_long=8 \
  ac_cv_alignof_double=8 \
  ac_cv_alignof_max_align_t=8 \
  ac_cv_have_int_max=yes \
  ac_cv_have_long_double=yes \
  ac_cv_c_bigendian=no \
  ac_cv_member_struct_stat_st_mtim=yes \
  ac_cv_func_stat64=yes \
  ac_cv_func_fstat64=yes \
  ac_cv_func_lstat64=yes \
  ac_cv_func_fstatat64=yes \
  ac_cv_header_ffi_h=no \
  ac_cv_lib_ffi_ffi_call=no \
  ac_cv_lib_bz2_BZ2_bzlibVersion=no \
  ac_cv_lib_lzma_lzma_code=no \
  ac_cv_lib_uuid_uuid_generate=no \
  2>&1 | tee "${BUILD_DIR}/configure.log"

echo "=== Patching for iOS ==="
# Disable features not available on iOS
sed -i '' 's/#define HAVE_FORKPTY 1/\/\* #undef HAVE_FORKPTY \*\//' pyconfig.h
sed -i '' 's/#define HAVE_VFORK 1/\/\* #undef HAVE_VFORK \*\//' pyconfig.h
# Disable ctypes module (requires libffi which isn't available for iOS target)
sed -i '' 's/^_ctypes /#_ctypes /' Modules/Setup.stdlib
# Disable bz2, lzma, dbm, uuid modules (not available in iOS SDK)
sed -i '' 's/^_lzma /#_lzma /' Modules/Setup.stdlib
sed -i '' 's/^_bz2 /#_bz2 /' Modules/Setup.stdlib
sed -i '' 's/^_dbm /#_dbm /' Modules/Setup.stdlib
sed -i '' 's/^_uuid /#_uuid /' Modules/Setup.stdlib

echo "=== Building CPython for iOS arm64 ==="
make -j$(sysctl -n hw.logicalcpu) \
  2>&1 | tee "${BUILD_DIR}/build.log"

echo "=== Installing to output ==="
rm -rf "${OUTPUT_DIR}"
make install DESTDIR="${OUTPUT_DIR}" \
  2>&1 | tee "${BUILD_DIR}/install.log"

# Copy the static library (built in the source tree)
LIBRARY="${PYTHON_SRC}/libpython${PYTHON_VERSION%.*}.a"

echo ""
echo "=== Build Complete ==="
echo "Library:  ${LIBRARY}"
ls -la "${LIBRARY}" 2>/dev/null || echo "WARNING: Library not found"

echo ""
echo "=== Copying to project ==="
mkdir -p "${PROJECT_DIR}/ios/lib/" "${PROJECT_DIR}/ios/include/"
cp "${LIBRARY}" "${PROJECT_DIR}/ios/lib/"
# Copy headers from framework install path
HEADERS_DIR="$(find "${BUILD_DIR}" -path "*/Python.framework/Headers" -type d 2>/dev/null | head -1)"
if [ -d "${HEADERS_DIR}" ]; then
  cp -R "${HEADERS_DIR}/" "${PROJECT_DIR}/ios/include/"
  echo "Headers copied from ${HEADERS_DIR}"
else
  echo "WARNING: Headers not found, copying from source"
  cp -R "${PYTHON_SRC}/Include/" "${PROJECT_DIR}/ios/include/"
  cp "${PYTHON_SRC}/pyconfig.h" "${PROJECT_DIR}/ios/include/"
fi

echo "Done!"
