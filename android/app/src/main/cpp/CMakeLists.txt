cmake_minimum_required(VERSION 3.13)
project(appmodules)

# Builds libappmodules.so with RN autolinking + AndroidBridge.cpp (auto-picked by glob)
include(${CMAKE_CURRENT_SOURCE_DIR}/../../../../../node_modules/react-native/ReactAndroid/cmake-utils/ReactNative-application.cmake)
target_sources(appmodules PRIVATE
        ${REACT_ANDROID_DIR}/cmake-utils/default-app-setup/OnLoad.cpp
)
# Python bridge source outside this directory
set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../..)
set(CPP_DIR ${PROJECT_ROOT}/cpp)
target_sources(appmodules PRIVATE ${CPP_DIR}/PythonBridge.cpp ${CPP_DIR}/PythonBridge2.cpp)

target_include_directories(appmodules PRIVATE
    ${CPP_DIR}
    ${PROJECT_ROOT}/android/include
)

# Prebuilt libpython3.13.so
set(JNI_LIBS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
add_library(libpython SHARED IMPORTED)
set_target_properties(libpython PROPERTIES
    IMPORTED_LOCATION ${JNI_LIBS_DIR}/libpython3.13.so
)

target_link_libraries(appmodules
    libpython
    log
)

target_compile_features(appmodules PRIVATE cxx_std_17)
target_compile_options(appmodules PRIVATE -fexceptions -frtti)
