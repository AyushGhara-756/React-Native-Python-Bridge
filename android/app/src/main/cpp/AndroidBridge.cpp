#include <jni.h>
#include <string>
#include <android/log.h>
#include "PythonBridge.h"

#define TAG "PythonBridge"

extern "C" {

static PyObject *javaToPython(JNIEnv *env, jobject obj) {
    if (!obj) {
        Py_RETURN_NONE;
    }

    jclass objClass = env->GetObjectClass(obj);

    // String
    jclass arrayListClass = env->FindClass("java/util/ArrayList");
    if (env->IsInstanceOf(obj, arrayListClass)) {
        jmethodID sizeMethod = env->GetMethodID(
                arrayListClass,
                "size",
                "()I"
        );
        if (env->CallIntMethod(obj, sizeMethod) == 1) {
            jmethodID getMethod = env->GetMethodID(
                    arrayListClass,
                    "get",
                    "(I)Ljava/lang/Object;"
            );
            jobject element = env->CallObjectMethod(obj, getMethod, 0);
            jclass stringClass = env->FindClass("java/lang/String");
            if (element && env->IsInstanceOf(element, stringClass)) {
                jstring str = (jstring) element;
                const char *utf = env->GetStringUTFChars(str, nullptr);
                PyObject *pyStr = PyUnicode_FromString(utf);
                env->ReleaseStringUTFChars(str, utf);
                env->DeleteLocalRef(element);
                env->DeleteLocalRef(stringClass);
                env->DeleteLocalRef(arrayListClass);
                return pyStr;
            }
            env->DeleteLocalRef(element);
            env->DeleteLocalRef(stringClass);
        }
    }
    env->DeleteLocalRef(arrayListClass);

    // Long / Integer
    jclass longClass = env->FindClass("java/lang/Long");
    if (env->IsInstanceOf(obj, longClass)) {
        jmethodID longVal = env->GetMethodID(longClass, "longValue", "()J");
        jlong val = env->CallLongMethod(obj, longVal);
        env->DeleteLocalRef(longClass);
        env->DeleteLocalRef(objClass);
        return PyLong_FromLongLong(val);
    }
    env->DeleteLocalRef(longClass);

    jclass intClass = env->FindClass("java/lang/Integer");
    if (env->IsInstanceOf(obj, intClass)) {
        jmethodID intVal = env->GetMethodID(intClass, "intValue", "()I");
        jint val = env->CallIntMethod(obj, intVal);
        env->DeleteLocalRef(intClass);
        env->DeleteLocalRef(objClass);
        return PyLong_FromLong(val);
    }
    env->DeleteLocalRef(intClass);

    // Double / Float
    jclass doubleClass = env->FindClass("java/lang/Double");
    if (env->IsInstanceOf(obj, doubleClass)) {
        jmethodID doubleVal = env->GetMethodID(doubleClass, "doubleValue", "()D");
        jdouble val = env->CallDoubleMethod(obj, doubleVal);
        env->DeleteLocalRef(doubleClass);
        env->DeleteLocalRef(objClass);
        return PyFloat_FromDouble(val);
    }
    env->DeleteLocalRef(doubleClass);

    // Boolean
    jclass boolClass = env->FindClass("java/lang/Boolean");
    if (env->IsInstanceOf(obj, boolClass)) {
        jmethodID boolVal = env->GetMethodID(boolClass, "booleanValue", "()Z");
        jboolean val = env->CallBooleanMethod(obj, boolVal);
        env->DeleteLocalRef(boolClass);
        env->DeleteLocalRef(objClass);
        if (val) { Py_RETURN_TRUE; } else { Py_RETURN_FALSE; }
    }
    env->DeleteLocalRef(boolClass);

    // String
    jclass stringClass = env->FindClass("java/lang/String");
    if (env->IsInstanceOf(obj, stringClass)) {
        jstring str = (jstring) obj;
        const char *utf = env->GetStringUTFChars(str, nullptr);
        PyObject *pyStr = PyUnicode_FromString(utf);
        env->ReleaseStringUTFChars(str, utf);
        env->DeleteLocalRef(stringClass);
        env->DeleteLocalRef(objClass);
        return pyStr;
    }
    env->DeleteLocalRef(stringClass);

    // ArrayList (JS arrays arrive as ArrayList on Android)
    jclass listClass = env->FindClass("java/util/ArrayList");
    if (env->IsInstanceOf(obj, listClass)) {
        jmethodID size = env->GetMethodID(listClass, "size", "()I");
        jmethodID get = env->GetMethodID(listClass, "get", "(I)Ljava/lang/Object;");
        jint len = env->CallIntMethod(obj, size);

        PyObject *pyList = PyList_New(len);
        for (jint i = 0; i < len; i++) {
            jobject element = env->CallObjectMethod(obj, get, i);
            PyObject *pyElem = javaToPython(env, element);
            PyList_SetItem(pyList, i, pyElem);
            env->DeleteLocalRef(element);
        }
        env->DeleteLocalRef(listClass);
        env->DeleteLocalRef(objClass);
        return pyList;
    }
    env->DeleteLocalRef(listClass);

    // HashMap (JS objects arrive as HashMap)
    jclass mapClass = env->FindClass("java/util/HashMap");
    if (env->IsInstanceOf(obj, mapClass)) {
        jmethodID entrySet = env->GetMethodID(mapClass, "entrySet", "()Ljava/util/Set;");
        jobject entries = env->CallObjectMethod(obj, entrySet);

        jclass setClass = env->GetObjectClass(entries);
        jmethodID toArray = env->GetMethodID(setClass, "toArray", "()[Ljava/lang/Object;");
        jobjectArray entryArr = (jobjectArray) env->CallObjectMethod(entries, toArray);
        jsize entryLen = env->GetArrayLength(entryArr);

        PyObject *pyDict = PyDict_New();
        jclass entryClass = env->FindClass("java/util/Map$Entry");
        jmethodID getKey = env->GetMethodID(entryClass, "getKey", "()Ljava/lang/Object;");
        jmethodID getValue = env->GetMethodID(entryClass, "getValue", "()Ljava/lang/Object;");

        for (jsize i = 0; i < entryLen; i++) {
            jobject entry = env->GetObjectArrayElement(entryArr, i);
            jobject keyObj = env->CallObjectMethod(entry, getKey);
            jobject valObj = env->CallObjectMethod(entry, getValue);

            PyObject *pyKey = javaToPython(env, keyObj);
            PyObject *pyVal = javaToPython(env, valObj);
            PyDict_SetItem(pyDict, pyKey, pyVal);
            Py_DECREF(pyKey);
            Py_DECREF(pyVal);

            env->DeleteLocalRef(keyObj);
            env->DeleteLocalRef(valObj);
            env->DeleteLocalRef(entry);
        }

        env->DeleteLocalRef(entryArr);
        env->DeleteLocalRef(entryClass);
        env->DeleteLocalRef(setClass);
        env->DeleteLocalRef(entries);
        env->DeleteLocalRef(mapClass);
        env->DeleteLocalRef(objClass);
        return pyDict;
    }
    env->DeleteLocalRef(mapClass);

    env->DeleteLocalRef(objClass);
    Py_RETURN_NONE;
}

JNIEXPORT jboolean
JNICALL
Java_com_rnpythonbridge_PythonBridgeModule_nativeInitialize(
        JNIEnv *env, jobject thiz, jstring pythonHome, jstring resourcePath) {
    const char *home = pythonHome ? env->GetStringUTFChars(pythonHome, nullptr) : nullptr;
    const char *resPath = resourcePath ? env->GetStringUTFChars(resourcePath, nullptr) : nullptr;

    bool ok = rnpythonbridge::PythonBridge::getInstance().initialize_v2(home, resPath);
    if (!ok) {
        const char *err = PythonBridge_getLastError();
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Init failed: %s", err ? err : "unknown");
    } else {
        __android_log_print(ANDROID_LOG_INFO, TAG, "Python initialized successfully");
    }

    if (home) env->ReleaseStringUTFChars(pythonHome, home);
    if (resPath) env->ReleaseStringUTFChars(resourcePath, resPath);

    return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring
JNICALL
Java_com_rnpythonbridge_PythonBridgeModule_nativeCallPythonArgs(
        JNIEnv *env, jobject thiz, jstring moduleName, jstring functionName, jobject argsList) {
    const char *mod = env->GetStringUTFChars(moduleName, nullptr);
    const char *func = env->GetStringUTFChars(functionName, nullptr);

    PyObject *pyArgs;
    if (argsList == nullptr) {
        pyArgs = PyTuple_New(0);
    } else {
        jclass listClass = env->FindClass("java/util/ArrayList");
        if (!env->IsInstanceOf(argsList, listClass)) {
            env->DeleteLocalRef(listClass);
            pyArgs = PyTuple_New(0);
        } else {
            jmethodID size = env->GetMethodID(listClass, "size", "()I");
            jmethodID get = env->GetMethodID(listClass, "get", "(I)Ljava/lang/Object;");
            jint len = env->CallIntMethod(argsList, size);

            pyArgs = PyTuple_New(len);
            for (jint i = 0; i < len; i++) {
                jobject element = env->CallObjectMethod(argsList, get, i);
                PyObject *pyElem = javaToPython(env, element);
                PyTuple_SetItem(pyArgs, i, pyElem);
                env->DeleteLocalRef(element);
            }
            env->DeleteLocalRef(listClass);
        }
    }

    std::string result = rnpythonbridge::PythonBridge::getInstance().callPythonFunction(mod, func,
                                                                                        pyArgs);

    const char *lastError = PythonBridge_getLastError();
    if (lastError && lastError[0]) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Error: %s", lastError);
    }

    Py_DECREF(pyArgs);
    env->ReleaseStringUTFChars(moduleName, mod);
    env->ReleaseStringUTFChars(functionName, func);

    return env->NewStringUTF(result.c_str());
}

JNIEXPORT jstring
JNICALL
Java_com_rnpythonbridge_PythonBridgeModule_nativeCallPythonAny(
        JNIEnv *env, jobject thiz, jstring moduleName, jstring functionName, jobject arg) {
    const char *mod = env->GetStringUTFChars(moduleName, nullptr);
    const char *func = env->GetStringUTFChars(functionName, nullptr);

    // Convert Java object to PyObject using javaToPython
    PyObject *pyObj = javaToPython(env, arg);

    // Wrap in single-element tuple to match iOS behavior (Python gets one arg)
    PyObject *pyArgs = PyTuple_Pack(1, pyObj);
    Py_DECREF(pyObj);

    std::string result = rnpythonbridge::PythonBridge::getInstance().callPythonFunction(mod, func,
                                                                                        pyArgs);

    Py_DECREF(pyArgs);

    const char *lastError = PythonBridge_getLastError();
    if (lastError && lastError[0]) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Error: %s", lastError);
    }

    env->ReleaseStringUTFChars(moduleName, mod);
    env->ReleaseStringUTFChars(functionName, func);

    return env->NewStringUTF(result.c_str());
}

JNIEXPORT jstring
JNICALL
Java_com_rnpythonbridge_PythonBridgeModule_nativeGetLastError(
        JNIEnv *env, jobject thiz) {
    const char *err = PythonBridge_getLastError();
    return env->NewStringUTF(err && err[0] ? err : "");
}

} // extern "C"
