package com.example.zoo_study

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.ByteArrayOutputStream
import kotlin.math.hypot

class StudyDetectorBridge(private val activity: Activity, flutterEngine: FlutterEngine) {
    private val worker = Executors.newSingleThreadExecutor()
    private val recognizer by lazy {
        TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
    }
    private var hands: HandLandmarker? = null
    private var previousTips = emptyList<Pair<Float, Float>>()
    private var previousTime = 0L
    private var reading = false

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "study_detector/desk_text")
            .setMethodCallHandler { call, result ->
                if (call.method == "keepAwake") {
                    val flag = android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    if (call.argument<Boolean>("enabled") == true) activity.window.addFlags(flag)
                    else activity.window.clearFlags(flag)
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "reset") {
                    worker.execute { previousTips = emptyList(); previousTime = 0L }
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "analyze" && call.method != "prepare") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null || reading) {
                    result.error("ANALYSIS_UNAVAILABLE", "画像が未指定、または分析中です", null)
                    return@setMethodCallHandler
                }
                reading = true
                worker.execute {
                    try {
                        val data = if (call.method == "prepare") prepare(path, call.argument<Map<String, Number>>("region"), call.argument<List<Map<String, Number>>>("masks") ?: emptyList()) else analyze(path)
                        activity.runOnUiThread { reading = false; result.success(data) }
                    } catch (error: Exception) {
                        previousTips = emptyList()
                        activity.runOnUiThread {
                            reading = false
                            result.error("ANALYSIS_FAILED", error.message, null)
                        }
                    }
                }
            }
    }

    // OCR and hand landmarks use the same upright pixels and coordinate space.
    private fun readBitmap(path: String): Bitmap {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        var sample = 1
        while (maxOf(options.outWidth, options.outHeight) / sample > 2048) sample *= 2
        val bitmap = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }) ?: throw IllegalArgumentException("画像を読み込めません")
        val orientation = ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
        }
        val upright = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        if (upright !== bitmap) bitmap.recycle()
        return upright
    }

    // Face-only mode skips OCR, hands and YOLO. Return upright pixels so the
    // Flutter face plugin and the displayed overlay share one coordinate space.
    private fun normalizedRect(region: Map<String, Number>, width: Int, height: Int): android.graphics.Rect {
        val left = region["left"]?.toDouble() ?: throw IllegalArgumentException("解析範囲が未指定です")
        val top = region["top"]?.toDouble() ?: throw IllegalArgumentException("解析範囲が未指定です")
        val right = region["right"]?.toDouble() ?: throw IllegalArgumentException("解析範囲が未指定です")
        val bottom = region["bottom"]?.toDouble() ?: throw IllegalArgumentException("解析範囲が未指定です")
        require(listOf(left, top, right, bottom).all { it.isFinite() } &&
            left >= 0 && top >= 0 && right <= 1 && bottom <= 1 && right > left && bottom > top) {
            "解析範囲が不正です"
        }
        val x1 = kotlin.math.floor(left * width).toInt().coerceIn(0, width - 1)
        val y1 = kotlin.math.floor(top * height).toInt().coerceIn(0, height - 1)
        val x2 = kotlin.math.ceil(right * width).toInt().coerceIn(x1 + 1, width)
        val y2 = kotlin.math.ceil(bottom * height).toInt().coerceIn(y1 + 1, height)
        return android.graphics.Rect(x1, y1, x2, y2)
    }

    private fun prepare(path: String, region: Map<String, Number>?, masks: List<Map<String, Number>>): Map<String, Any> {
        val bitmap = readBitmap(path)
        var selected = bitmap
        try {
            if (region != null) {
                val rect = normalizedRect(region, bitmap.width, bitmap.height)
                selected = Bitmap.createBitmap(bitmap, rect.left, rect.top, rect.width(), rect.height())
            }
            if (masks.isNotEmpty()) {
                val mutable = selected.copy(Bitmap.Config.ARGB_8888, true)
                    ?: throw IllegalStateException("プレビューを保護できません")
                if (selected !== bitmap) selected.recycle()
                selected = mutable
                val canvas = android.graphics.Canvas(selected)
                val paint = android.graphics.Paint().apply { color = 0xff30343b.toInt() }
                for (mask in masks) canvas.drawRect(normalizedRect(mask, selected.width, selected.height), paint)
            }
            val bytes = ByteArrayOutputStream()
            selected.compress(Bitmap.CompressFormat.JPEG, 94, bytes)
            return mapOf("imageBytes" to bytes.toByteArray(),
                "imageWidth" to selected.width, "imageHeight" to selected.height)
        } finally {
            if (selected !== bitmap) selected.recycle()
            bitmap.recycle()
        }
    }
    private fun analyze(path: String): Map<String, Any> {
        val bitmap = readBitmap(path)
        try {
            val data = mutableMapOf<String, Any>(
                "lines" to 0, "characters" to 0, "areaRatio" to 0.0,
                "ocrAvailable" to false, "handAvailable" to false,
                "hands" to 0, "handNearText" to false, "handMoving" to false
            )
            val textRegions = mutableListOf<android.graphics.Rect>()
            val textBlocks = mutableListOf<Map<String, Any>>()
            try {
                val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)))
                val lines = text.textBlocks.flatMap { it.lines }
                    .filter { it.text.count { ch -> ch.isLetterOrDigit() } >= 2 }
                val characters = lines.sumOf { line -> line.text.count { it.isLetterOrDigit() } }
                val area = lines.sumOf { line ->
                    val rect = line.boundingBox
                    if (rect == null) 0.0 else rect.width().toDouble() * rect.height()
                }
                data["ocrAvailable"] = true
                data["lines"] = lines.size
                data["characters"] = characters
                data["areaRatio"] = (area / (bitmap.width.toDouble() * bitmap.height)).coerceIn(0.0, 1.0)
                // Expand each text block separately, avoiding one large background-spanning box.
                text.textBlocks.filter { block ->
                    block.lines.count { line -> line.text.count { it.isLetterOrDigit() } >= 2 } >= 2
                }.mapNotNullTo(textRegions) { it.boundingBox }
                for (block in text.textBlocks) {
                    val rect = block.boundingBox ?: continue
                    val usefulLines = block.lines.filter { line -> line.text.count { it.isLetterOrDigit() } >= 2 }
                    textBlocks.add(mapOf(
                        "left" to rect.left.toDouble() / bitmap.width,
                        "top" to rect.top.toDouble() / bitmap.height,
                        "right" to rect.right.toDouble() / bitmap.width,
                        "bottom" to rect.bottom.toDouble() / bitmap.height,
                        "lines" to usefulLines.size,
                        "characters" to usefulLines.sumOf { line -> line.text.count { it.isLetterOrDigit() } }
                    ))
                }
            } catch (error: Exception) { data["ocrError"] = error.message ?: "文字認識エラー" }
            try {
                val detector = hands ?: HandLandmarker.createFromOptions(activity,
                    HandLandmarker.HandLandmarkerOptions.builder()
                        .setBaseOptions(BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build())
                        .setNumHands(2)
                        .setMinHandDetectionConfidence(0.5f)
                        .setMinHandPresenceConfidence(0.5f)
                        .build()).also { hands = it }
                // MPImage.close() recycles its Bitmap; give it a separate copy.
                val longest = maxOf(bitmap.width, bitmap.height)
                val handBitmap = if (longest > 640) {
                    val scale = 640.0 / longest
                    Bitmap.createScaledBitmap(bitmap, maxOf(1, (bitmap.width * scale).toInt()),
                        maxOf(1, (bitmap.height * scale).toInt()), true)
                } else bitmap.copy(Bitmap.Config.ARGB_8888, false)
                    ?: throw IllegalStateException("手の認識画像を準備できません")
                val mpImage = BitmapImageBuilder(handBitmap).build()
                val result = try { detector.detect(mpImage) } finally { mpImage.close() }
                val tips = result.landmarks().map { points -> points[8].x() to points[8].y() }
                val nearText = tips.any { tip -> textRegions.any { rect ->
                    val px = tip.first * bitmap.width
                    val py = tip.second * bitmap.height
                    px >= rect.left - bitmap.width * 0.12 && px <= rect.right + bitmap.width * 0.12 &&
                        py >= rect.top - bitmap.height * 0.12 && py <= rect.bottom + bitmap.height * 0.12
                } }
                val now = android.os.SystemClock.elapsedRealtime()
                val comparable = now - previousTime in 500..12000
                val moving = comparable && tips.any { tip ->
                    val distance = previousTips.minOfOrNull { prev ->
                        hypot((tip.first - prev.first).toDouble(), (tip.second - prev.second).toDouble())
                    }
                    distance != null && distance in 0.008..0.30
                }
                previousTips = tips
                previousTime = now
                data["handAvailable"] = true
                data["hands"] = tips.size
                data["handNearText"] = nearText
                // Spatial filtering belongs to Dart, after screen text is excluded.
                data["handMoving"] = moving
                data["handPoints"] = tips.map { mapOf("x" to it.first.toDouble(), "y" to it.second.toDouble()) }
                data["handLandmarks"] = result.landmarks().map { points ->
                    points.map { mapOf("x" to it.x().toDouble(), "y" to it.y().toDouble()) }
                }
            } catch (error: Exception) {
                previousTips = emptyList()
                data["handError"] = error.message ?: "手の認識エラー"
            } catch (error: LinkageError) {
                previousTips = emptyList()
                data["handError"] = error.message ?: "この端末では手の認識ライブラリを利用できません"
            }
            data["textBlocks"] = textBlocks
            data["imageWidth"] = bitmap.width
            data["imageHeight"] = bitmap.height
            // YOLO's byte-array path does not apply JPEG EXIF orientation. Supply
            // the same upright image used by OCR, entirely in memory.
            val bytes = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 94, bytes)
            data["imageBytes"] = bytes.toByteArray()
            return data
        } finally { bitmap.recycle() }
    }

    fun close() {
        // Queue resource release after any in-flight inference.
        worker.execute { hands?.close(); recognizer.close() }
        worker.shutdown()

    }
}
