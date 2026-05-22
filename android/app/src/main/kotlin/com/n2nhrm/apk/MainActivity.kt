package com.n2nhrm.apk

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Set FLAG_SECURE immediately in onCreate to prevent screenshots
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        android.util.Log.d("MainActivity", "✅ FLAG_SECURE set in onCreate")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Security channel for FLAG_SECURE
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.n2nhrm.apk.security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFlagSecure" -> {
                        try {
                            // Ensure flag is set on the main thread
                            runOnUiThread {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                                android.util.Log.d("MainActivity", "✅ FLAG_SECURE confirmed set from Dart")
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "❌ Error setting FLAG_SECURE: ${e.message}")
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.n2nhrm.apk.media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToMediaStore" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                            val filename = call.argument<String>("filename")
                                ?: "image_${System.currentTimeMillis()}.jpg"
                            val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"

                            if (bytes == null) {
                                result.error("INVALID_ARGS", "bytes is null", null)
                                return@setMethodCallHandler
                            }

                            val savedUri = saveImageToMediaStore(bytes, filename, mimeType)
                            if (savedUri != null) {
                                result.success(savedUri)
                            } else {
                                result.error("SAVE_FAILED", "Could not save image", null)
                            }
                        } catch (e: Exception) {
                            result.error("EXCEPTION", e.message, null)
                        }
                    }

                    "saveFileToMediaStore" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                            val filename = call.argument<String>("filename")
                                ?: "file_${System.currentTimeMillis()}"
                            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

                            if (bytes == null) {
                                result.error("INVALID_ARGS", "bytes is null", null)
                                return@setMethodCallHandler
                            }

                            val savedUri = saveFileToMediaStore(bytes, filename, mimeType)
                            if (savedUri != null) {
                                result.success(savedUri)
                            } else {
                                result.error("SAVE_FAILED", "Could not save file", null)
                            }
                        } catch (e: Exception) {
                            result.error("EXCEPTION", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun saveImageToMediaStore(bytes: ByteArray, filename: String, mimeType: String): String? {
        val resolver = contentResolver

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/N2NHRM")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(collection, contentValues) ?: return null

        try {
            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            } ?: return null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }

            return uri.toString()
        } catch (e: IOException) {
            resolver.delete(uri, null, null)
            return null
        }
    }

    private fun saveFileToMediaStore(bytes: ByteArray, filename: String, mimeType: String): String? {
        val resolver = contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/SODHRM")
            }

            val uri = resolver.insert(collection, contentValues) ?: return null

            try {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                    outputStream.flush()
                } ?: return null

                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                return uri.toString()
            } catch (e: IOException) {
                resolver.delete(uri, null, null)
                return null
            }
        } else {
            // Pre-Q fallback: write to Downloads directory and return file:// path
            try {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val dir = java.io.File(downloadsDir, "SODHRM")
                if (!dir.exists()) dir.mkdirs()
                val file = java.io.File(dir, filename)
                file.outputStream().use { it.write(bytes) }
                return file.toURI().toString()
            } catch (e: IOException) {
                return null
            }
        }
    }

}
