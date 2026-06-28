package com.rnpythonbridge

import android.app.Application
import android.util.Log
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost

class MainApplication : Application(), ReactApplication {

  override val reactHost: ReactHost by lazy {
    getDefaultReactHost(
      context = applicationContext,
      packageList =
        PackageList(this).packages.apply {
          // Packages that cannot be autolinked yet can be added manually here, for example:
          // add(MyReactNativePackage())
          add(PythonBridgePackage())
        },
    )
  }

  override fun onCreate() {
    super.onCreate()
    try {
      System.loadLibrary("python3.13")
    } catch (e: UnsatisfiedLinkError) {
      Log.e("PythonBridge", "Failed to load native library: ${e.message}")
    }
    loadReactNative(this)
  }
}
