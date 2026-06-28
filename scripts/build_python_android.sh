#!/bin/bash
set -euo pipefail

PYTHON_VERSION="3.13.14"
PYTHON_DIR="Python-${PYTHON_VERSION}"
PYTHON_TAR="${PYTHON_DIR}.tar.xz"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TAR}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON_SRC="${PROJECT_DIR}/python/${PYTHON_DIR}"
BUILD_DIR="${PROJECT_DIR}/python/build_android"
HOST_PYTHON="${BUILD_DIR}/host-python/bin/python3"

NDK_VERSION="27.1.12297006"
NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK:-${HOME}/Android/Sdk/ndk/${NDK_VERSION}}}"
API_LEVEL=24

HOST_OS="linux"
HOST_ARCH=$(uname -m)
case "$(uname -s)" in
    Darwin) HOST_OS="darwin" ;;
    Linux)  HOST_OS="linux" ;;
    MINGW*|MSYS*) HOST_OS="windows" ;;
esac

TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/${HOST_OS}-${HOST_ARCH}"

declare -A ARCH_MAP
ARCH_MAP["arm64-v8a"]="aarch64-linux-android"
ARCH_MAP["armeabi-v7a"]="armv7a-linux-androideabi"
ARCH_MAP["x86_64"]="x86_64-linux-android"
ARCH_MAP["x86"]="i686-linux-android"

declare -A ARCH_HOST
ARCH_HOST["arm64-v8a"]="aarch64-linux-android"
ARCH_HOST["armeabi-v7a"]="arm-linux-androideabi"
ARCH_HOST["x86_64"]="x86_64-linux-android"
ARCH_HOST["x86"]="i686-linux-android"

declare -A ARCH_CFLAGS
ARCH_CFLAGS["arm64-v8a"]="-march=armv8-a"
ARCH_CFLAGS["armeabi-v7a"]="-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
ARCH_CFLAGS["x86_64"]="-march=x86-64"
ARCH_CFLAGS["x86"]="-march=i686"

mkdir -p "${BUILD_DIR}"

if [ ! -d "${PYTHON_SRC}" ]; then
  if [ ! -f "${BUILD_DIR}/${PYTHON_TAR}" ]; then
    echo "=== Downloading CPython ${PYTHON_VERSION} ==="
    curl -L --fail "${PYTHON_URL}" -o "${BUILD_DIR}/${PYTHON_TAR}"
  fi
  echo "=== Extracting ==="
  tar xf "${BUILD_DIR}/${PYTHON_TAR}" -C "${PROJECT_DIR}/python/"
fi

# Build host Python (needed for cross-compilation)
if [ ! -f "${HOST_PYTHON}" ]; then
  echo ""
  echo "============================================"
  echo "  Building host Python ${PYTHON_VERSION}"
  echo "============================================"
  echo ""
  mkdir -p "${BUILD_DIR}/host-python-build"
  cd "${PYTHON_SRC}"
  make distclean 2>/dev/null || true
  ./configure \
    --prefix="${BUILD_DIR}/host-python" \
    --enable-optimizations \
    --without-ensurepip \
    2>&1 | tee "${BUILD_DIR}/host-python-build/configure.log"
  make -j$(nproc) 2>&1 | tee "${BUILD_DIR}/host-python-build/build.log"
  make install 2>&1 | tee "${BUILD_DIR}/host-python-build/install.log"
  cd "${PROJECT_DIR}"
  echo "=== Host Python built at ${HOST_PYTHON} ==="
fi

build_for_abi() {
  local ABI="$1"
  local TARGET="${ARCH_MAP[$ABI]}"
  local HOST="${ARCH_HOST[$ABI]}"
  local ARCH_EXTRA="${ARCH_CFLAGS[$ABI]}"
  local ABI_BUILD_DIR="${BUILD_DIR}/${ABI}"
  local ABI_OUTPUT="${ABI_BUILD_DIR}/output"

  echo ""
  echo "============================================"
  echo "  Building for ${ABI} (${TARGET})"
  echo "============================================"
  echo ""

  mkdir -p "${ABI_BUILD_DIR}" "${ABI_OUTPUT}"

  export CC="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
  export CXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"
  export AR="${TOOLCHAIN}/bin/llvm-ar"
  export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
  export LD="${TOOLCHAIN}/bin/ld"
  export STRIP="${TOOLCHAIN}/bin/llvm-strip"
  export CFLAGS="-fPIC ${ARCH_EXTRA} -D__ANDROID__ -DANDROID -fstack-protector-strong"
  export CXXFLAGS="${CFLAGS}"
  export LDFLAGS="-fPIC -L${ABI_OUTPUT}/lib -Wl,-soname,libpython3.13.so"
  export PATH="${TOOLCHAIN}/bin:${PATH}"

  cd "${PYTHON_SRC}"

  # Clean
  make distclean 2>/dev/null || true

  echo "--- Configuring for ${ABI} ---"
  ./configure \
    --host="${HOST}" \
    --build="${HOST_ARCH}-${HOST_OS}-gnu" \
    --enable-shared \
    --with-build-python="${HOST_PYTHON}" \
    --without-ensurepip \
    --disable-test-modules \
    --with-pkg-config=no \
    --prefix="${ABI_OUTPUT}" \
    ac_cv_file__dev_ptmx=no \
    ac_cv_file__dev_ptc=no \
    ac_cv_func_fork=no \
    ac_cv_func_fork_works=no \
    ac_cv_func_vfork=no \
    ac_cv_func_vfork_works=no \
    ac_cv_func_system=no \
    ac_cv_func_pipe=no \
    ac_cv_func_pipe2=no \
    ac_cv_func_dlopen=yes \
    ac_cv_func_dlclose=yes \
    ac_cv_func_dlsym=yes \
    ac_cv_have_long_long_format=yes \
    ac_cv_have_int_max=yes \
    ac_cv_have_long_double=yes \
    ac_cv_c_bigendian=no \
    ac_cv_cxx_compile_cxx17=yes \
    ac_cv_func_stat64=yes \
    ac_cv_func_fstat64=yes \
    ac_cv_func_lstat64=yes \
    ac_cv_func_fstatat64=yes \
    ac_cv_header_libintl_h=no \
    ac_cv_lib_intl_textdomain=no \
    ac_cv_lib_intl_bindtextdomain=no \
    ac_cv_lib_intl_gettext=no \
    ac_cv_lib_ffi_ffi_call=no \
    ac_cv_lib_bz2_BZ2_bzlibVersion=no \
    ac_cv_lib_lzma_lzma_code=no \
    ac_cv_lib_uuid_uuid_generate=no \
    ac_cv_lib_ssl_SSL_new=no \
    ac_cv_lib_crypto_CRYPTO_new_ex_data=no \
    ac_cv_lib_sqlite3_sqlite3_open=no \
    ac_cv_lib_readline_readline=no \
    ac_cv_lib_ncursesw_initscr=no \
    ac_cv_lib_panelw_new_panel=no \
    2>&1 | tee "${ABI_BUILD_DIR}/configure.log"

  echo "--- Patching pyconfig.h for Android ${ABI} ---"
  sed -i 's/#define HAVE_FORK 1/\/\* #undef HAVE_FORK \*\//' pyconfig.h
  sed -i 's/#define HAVE_FORKPTY 1/\/\* #undef HAVE_FORKPTY \*\//' pyconfig.h
  sed -i 's/#define HAVE_VFORK 1/\/\* #undef HAVE_VFORK \*\//' pyconfig.h
  sed -i 's/#define HAVE_PIPE 1/\/\* #undef HAVE_PIPE \*\//' pyconfig.h
  sed -i 's/#define HAVE_SYSTEM 1/\/\* #undef HAVE_SYSTEM \*\//' pyconfig.h
  sed -i 's/#define HAVE_FACCESSAT 1/\/\* #undef HAVE_FACCESSAT \*\//' pyconfig.h

  # Disable problem modules
  sed -i 's/^_ctypes /#_ctypes /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_lzma /#_lzma /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_bz2 /#_bz2 /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_dbm /#_dbm /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_uuid /#_uuid /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_sqlite3 /#_sqlite3 /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_ssl /#_ssl /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_hashlib /#_hashlib /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^readline /#_readline /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_curses /#_curses /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_curses_panel /#_curses_panel /' Modules/Setup.stdlib 2>/dev/null || true
  sed -i 's/^_posixsubprocess /#_posixsubprocess /' Modules/Setup.stdlib 2>/dev/null || true

  echo "--- Building for ${ABI} ---"
  make -j$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4) \
    2>&1 | tee "${ABI_BUILD_DIR}/build.log"

  echo "--- Installing for ${ABI} ---"
  rm -rf "${ABI_OUTPUT}"
  make install DESTDIR="" 2>&1 | tee "${ABI_BUILD_DIR}/install.log"

  local LIBRARY="${PYTHON_SRC}/libpython${PYTHON_VERSION%.*}.so"
  echo "Library: ${LIBRARY}"
  ls -la "${LIBRARY}" 2>/dev/null || echo "WARNING: Library not found"

  # Copy to project
  local GENERATED_DIR="${PROJECT_DIR}/android/generated/${ABI}"
  local JNI_DIR="${PROJECT_DIR}/android/app/src/main/jniLibs/${ABI}"
  local INCLUDE_DIR="${PROJECT_DIR}/android/include"
  local ASSETS_DIR="${PROJECT_DIR}/android/app/src/main/assets"

  mkdir -p "${GENERATED_DIR}" "${JNI_DIR}" "${INCLUDE_DIR}" "${ASSETS_DIR}"

  if [ -f "${LIBRARY}" ]; then
    cp "${LIBRARY}" "${GENERATED_DIR}/libpython3.13.so"
    cp "${LIBRARY}" "${JNI_DIR}/libpython3.13.so"
    echo "Copied library to ${GENERATED_DIR}/ and ${JNI_DIR}/"
    # Remove stale .a files
    rm -f "${JNI_DIR}/libpython3.13.a"
  fi

  if [ -f "${PYTHON_SRC}/pyconfig.h" ]; then
    mkdir -p "${INCLUDE_DIR}/cpython"
    cp "${PYTHON_SRC}/pyconfig.h" "${INCLUDE_DIR}/"
  fi

  local STDLIB_SRC="${ABI_OUTPUT}/lib/python${PYTHON_VERSION%.*}"
  if [ -d "${STDLIB_SRC}" ]; then
    rm -rf "${ASSETS_DIR}/python${PYTHON_VERSION%.*}"
    mkdir -p "${ASSETS_DIR}"
    cp -R "${STDLIB_SRC}" "${ASSETS_DIR}/python${PYTHON_VERSION%.*}"
    echo "Copied stdlib to ${ASSETS_DIR}/"
    du -sh "${ASSETS_DIR}/python${PYTHON_VERSION%.*}"
  fi

  cd "${PROJECT_DIR}"
  echo "=== Done building for ${ABI} ==="
}

# Build for all target architectures
for ABI in "${!ARCH_MAP[@]}"; do
  build_for_abi "$ABI"
done

# Copy platform-independent headers to android/include/
if [ -d "${PYTHON_SRC}/Include" ]; then
  mkdir -p "${PROJECT_DIR}/android/include"
  cp -R "${PYTHON_SRC}/Include/" "${PROJECT_DIR}/android/include/"
  if [ -f "${PYTHON_SRC}/pyconfig.h" ]; then
    cp "${PYTHON_SRC}/pyconfig.h" "${PROJECT_DIR}/android/include/"
  fi
  echo "Headers copied to android/include/"
fi

echo ""
echo "============================================"
echo "  All Android Python builds complete!"
echo "============================================"
echo ""
echo "To use in your project, these files were created:"
echo "  - android/generated/<abi>/libpython3.13.so"
echo "  - android/app/src/main/jniLibs/<abi>/libpython3.13.so"
echo "  - android/include/Python.h and other headers"
echo "  - android/app/src/main/assets/python3.13/ (stdlib)"
echo ""
echo "IMPORTANT: The CMakeLists.txt must be updated to link against .so instead of .a"
echo "Run ./gradlew :app:assembleDebug to build the app."
