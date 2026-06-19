package com.n2nhrm.apk

import io.flutter.embedding.engine.FlutterEngine
import android.util.Log

/**
 * Registers plugins for the background isolate.
 * WifiBssidPlugin is now auto-registered via GeneratedPluginRegistrant
 * since it implements FlutterPlugin.
 */
object DartPluginRegistrant {
    private const val TAG = "DartPluginRegistrant"
    
    @JvmStatic
    fun registerWith(flutterEngine: FlutterEngine) {
        Log.d(TAG, "registerWith called - plugins are auto-registered via GeneratedPluginRegistrant")
    }
    
    @JvmStatic
    fun ensureInitialized() {
        Log.d(TAG, "ensureInitialized called - plugins are auto-registered via GeneratedPluginRegistrant")
    }
}
