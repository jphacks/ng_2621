package com.example.zoo_study

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var studyDetector: StudyDetectorBridge? = null
    private var photoResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        studyDetector = StudyDetectorBridge(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoostudy/photos")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickPhoto") pickPhoto(result) else result.notImplemented()
            }
    }

    @Suppress("DEPRECATION")
    private fun pickPhoto(result: MethodChannel.Result) {
        if (photoResult != null) {
            result.error("photo_busy", "写真を選択中です", null)
            return
        }
        photoResult = result
        val intent = Intent(Intent.ACTION_PICK).apply {
            type = "image/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            // Use the installed Photos app directly, including on Android 11/12.
            // The system Photo Picker can fall back to DocumentsUI on these devices.
            try {
                startActivityForResult(
                    Intent(intent).setPackage("com.google.android.apps.photos"), PHOTO_REQUEST
                )
            } catch (_: ActivityNotFoundException) {
                startActivityForResult(Intent.createChooser(intent, "写真を選ぶ"), PHOTO_REQUEST)
            }
        } catch (_: Exception) {
            photoResult = null
            result.error("photo_unavailable", "写真を選べるフォト・ギャラリーアプリが見つかりません", null)
        }
    }

    @Deprecated("Activity result bridge for FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PHOTO_REQUEST) return
        val result = photoResult ?: return
        photoResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        // Cloud-backed Photos content can take time to download. Keep it off the UI thread.
        Thread {
            try {
                val photo = readPhoto(uri)
                runOnUiThread { result.success(photo) }
            } catch (_: PhotoTooLarge) {
                runOnUiThread { result.error("photo_too_large", "写真は1件10MB以内で選択してください", null) }
            } catch (_: Exception) {
                runOnUiThread { result.error("photo_read_failed", "写真を読み込めませんでした。通信を確認して選び直してください", null) }
            }
        }.start()
    }

    private fun readPhoto(uri: Uri): Map<String, Any> {
        val bytes = contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > MAX_PHOTO_BYTES) throw PhotoTooLarge()
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IllegalStateException("Photo stream unavailable")
        val name = try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        } catch (_: Exception) { null }
        val extension = when (contentResolver.getType(uri)) {
            "image/png" -> "png"
            "image/jpeg" -> "jpg"
            else -> "image"
        }
        return mapOf("name" to (name ?: "photo.$extension"), "bytes" to bytes)
    }

    override fun onDestroy() {
        studyDetector?.close()
        studyDetector = null
        super.onDestroy()
    }

    private class PhotoTooLarge : Exception()
    companion object {
        private const val PHOTO_REQUEST = 61041
        private const val MAX_PHOTO_BYTES = 10 * 1024 * 1024
    }
}
