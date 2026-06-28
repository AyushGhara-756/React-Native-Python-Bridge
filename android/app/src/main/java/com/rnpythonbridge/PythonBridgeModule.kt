package com.rnpythonbridge

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import java.io.File

class PythonBridgeModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val NAME = "RNPythonBridge"
        private const val TAG = "PythonBridge"
        private const val STDLIB_ASSET_PATH = "python3.13"
        private const val STDLIB_DIR_NAME = "python3.13"
        private const val SCRIPTS_ASSET_PATH = "python"
        private const val SCRIPTS_DIR_NAME = "python"
        @Volatile
        private var initialized = false
    }

    override fun getName(): String = NAME

    private fun ensureInitialized() {
        if (!initialized) {
            synchronized(this) {
                if (!initialized) {
                    initializePython(reactApplicationContext)
                    initialized = true
                }
            }
        }
    }

    private fun initializePython(context: Context) {
        val filesDir = context.filesDir
        val stdlibDir = File(filesDir, STDLIB_DIR_NAME)
        val scriptsDir = File(filesDir, SCRIPTS_DIR_NAME)

        try {
            if (!stdlibDir.exists()) {
                extractAssetDir(context, STDLIB_ASSET_PATH, stdlibDir)
            }
            extractAssetDir(context, SCRIPTS_ASSET_PATH, scriptsDir)
            val ok = nativeInitialize(stdlibDir.absolutePath, scriptsDir.absolutePath)
            if (!ok) {
                val err = nativeGetLastError()
                Log.e(TAG, "Python init failed: $err")
            } else {
                Log.i(TAG, "Python initialized: home=${stdlibDir.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Init error: ${e.message}", e)
        }
    }

    private fun extractAssetDir(context: Context, assetPath: String, destDir: File) {
        val assetManager = context.assets
        val entries = assetManager.list(assetPath) ?: return
        destDir.mkdirs()
        for (entry in entries) {
            val subPath = "$assetPath/$entry"
            val destFile = File(destDir, entry)
            if (assetManager.list(subPath)?.isNotEmpty() == true) {
                extractAssetDir(context, subPath, destFile)
            } else {
                try {
                    assetManager.open(subPath).use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to extract $subPath: ${e.message}")
                }
            }
        }
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun callPython(module: String, function: String, arg: ReadableArray?): String {
        ensureInitialized()
        val list = if (arg != null) readableArrayToList(arg) else ArrayList<Any?>()
        return nativeCallPythonAny(module, function, list)
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun callPythonArgs(module: String, function: String, args: ReadableArray?): String {
        ensureInitialized()
        val list = if (args != null) readableArrayToList(args) else ArrayList<Any?>()
        return nativeCallPythonArgs(module, function, list)
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun getError(): String {
        return nativeGetLastError()
    }

    @ReactMethod
    fun getLog(promise: Promise) {
        try {
            val logFile = File(reactApplicationContext.filesDir, "python_bridge.log")
            val log = if (logFile.exists()) logFile.readText() else "(no log)"
            promise.resolve(log)
        } catch (e: Exception) {
            promise.resolve("(error reading log: ${e.message})")
        }
    }

    private fun readableArrayToList(args: ReadableArray): ArrayList<Any?> {
        val list = ArrayList<Any?>()
        for (i in 0 until args.size()) {
            when (args.getType(i)) {
                ReadableType.Null -> list.add(null)
                ReadableType.Boolean -> list.add(args.getBoolean(i))
                ReadableType.Number -> {
                    val d = args.getDouble(i)
                    if (d % 1.0 == 0.0 && d >= Long.MIN_VALUE.toDouble() && d <= Long.MAX_VALUE.toDouble()) {
                        list.add(d.toLong())
                    } else {
                        list.add(d)
                    }
                }
                ReadableType.String -> list.add(args.getString(i))
                ReadableType.Array -> list.add(readableArrayToList(args.getArray(i)!!))
                ReadableType.Map -> list.add(readableMapToMap(args.getMap(i)!!))
            }
        }
        return list
    }

    private fun readableMapToMap(map: ReadableMap): Map<String, Any?> {
        val result = HashMap<String, Any?>()
        val iterator = map.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            when (map.getType(key)) {
                ReadableType.Null -> result[key] = null
                ReadableType.Boolean -> result[key] = map.getBoolean(key)
                ReadableType.Number -> {
                    val d = map.getDouble(key)
                    if (d % 1.0 == 0.0 && d >= Long.MIN_VALUE.toDouble() && d <= Long.MAX_VALUE.toDouble()) {
                        result[key] = d.toLong()
                    } else {
                        result[key] = d
                    }
                }
                ReadableType.String -> result[key] = map.getString(key)
                ReadableType.Array -> result[key] = readableArrayToList(map.getArray(key)!!)
                ReadableType.Map -> result[key] = readableMapToMap(map.getMap(key)!!)
            }
        }
        return result
    }

    private external fun nativeInitialize(pythonHome: String, resourcePath: String): Boolean
    private external fun nativeCallPythonArgs(module: String, function: String, args: Any?): String
    private external fun nativeCallPythonAny(module: String, function: String, arg: Any?): String
    private external fun nativeGetLastError(): String
}
