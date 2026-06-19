package com.n2nhrm.apk

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import androidx.annotation.Keep
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

@Keep
class WifiBssidPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        private const val TAG = "WifiBssidPlugin"
        private const val CHANNEL = "com.n2nhrm.apk.wifi_bssid"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
        Log.d(TAG, "WifiBssidPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        Log.d(TAG, "WifiBssidPlugin detached from engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getWifiBssid") {
            try {
                val bssid = getWifiBssid(context)
                result.success(bssid)
            } catch (e: Exception) {
                Log.e(TAG, "Error getting BSSID: ${e.message}")
                result.error("ERROR", e.message, null)
            }
        } else {
            result.notImplemented()
        }
    }

    private fun getWifiBssid(ctx: Context?): String {
        return try {
            val appContext = ctx ?: return ""
            val wifiManager = appContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return ""
            
            @Suppress("DEPRECATION")
            val wifiInfo = wifiManager.connectionInfo
            val bssid = wifiInfo.bssid
            
            Log.d(TAG, "Native BSSID read: $bssid")
            
            if (bssid != null && bssid != "02:00:00:00:00:00" && bssid != "00:00:00:00:00:00") {
                bssid
            } else {
                Log.w(TAG, "Invalid BSSID: $bssid")
                ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading BSSID: ${e.message}")
            ""
        }
    }
}
