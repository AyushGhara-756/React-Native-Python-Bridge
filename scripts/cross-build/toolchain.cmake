# Cross-compilation toolchain for iOS arm64
# Usage: cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake ..

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 15.1)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_SYSROOT iphoneos)

set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)
set(CMAKE_AR /usr/bin/ar)
set(CMAKE_STRIP /usr/bin/strip)

set(CMAKE_C_FLAGS "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=15.1")
set(CMAKE_CXX_FLAGS "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=15.1")
set(CMAKE_EXE_LINKER_FLAGS "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=15.1")
set(CMAKE_SHARED_LINKER_FLAGS "-arch arm64 -isysroot ${CMAKE_OSX_SYSROOT} -miphoneos-version-min=15.1")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
