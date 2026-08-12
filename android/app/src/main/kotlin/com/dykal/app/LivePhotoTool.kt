package com.dykal.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbMatrix
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

// BATCH J: Live Photo Fase 1 — trim + kompres + look preset 100% on-device.
//   Spek: uploads/FITUR-LIVE-PHOTO.md (roadmap Fase 1 = SIMPAN VIDEO + SHARE).
//   FFmpegKit sudah pension -> mesin video memakai Media3 Transformer (1.4.1,
//   signature API diverifikasi dari source tag 1.4.1: Listener onError memakai
//   ExportException, getProgress(ProgressHolder) wajib main thread).
//   Look/preset: 1 matriks 4x4 dari Dart -> RgbMatrix (video) + ColorMatrix (cover),
//   jadi cover & klip satu rasa. Semua method dipanggil dari main thread (MethodChannel).
@OptIn(UnstableApi::class)
class LivePhotoTool(messenger: BinaryMessenger, private val appContext: Context) {

    companion object {
        const val CHANNEL = "dykal/livephoto"
    }

    private var transformer: Transformer? = null
    private var pendingResult: MethodChannel.Result? = null
    private val progressHolder = ProgressHolder()

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "probe" -> handleProbe(call, result)
                "cover" -> handleCover(call, result)
                "start" -> handleStart(call, result)
                "progress" -> handleProgress(result)
                "cancel" -> {
                    try { transformer?.cancel() } catch (_: Exception) {}
                    cleanupJob()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cleanupJob() {
        transformer = null
        pendingResult = null
    }

    // Info video sumber: durasi + resolusi (dipakai UI buat slider & jujur soal ukuran)
    private fun handleProbe(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) { result.error("ARGS", "path kosong", null); return }
        try {
            val r = MediaMetadataRetriever()
            r.setDataSource(path)
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            r.release()
            result.success(mapOf("durMs" to dur, "width" to w, "height" to h))
        } catch (e: Exception) {
            result.error("PROBE_ERR", e.message, null)
        }
    }

    // Ambil 1 frame cover (+ look preset yang sama dengan klip) -> JPEG
    private fun handleCover(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val outPath = call.argument<String>("outPath")
        val timeUs = (call.argument<Number>("timeUs") ?: 0).toLong()
        val matrix = call.argument<List<Double>>("matrix")
        if (path == null || outPath == null) { result.error("ARGS", "path/outPath kosong", null); return }
        try {
            val r = MediaMetadataRetriever()
            r.setDataSource(path)
            var bmp = r.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            r.release()
            if (bmp == null) { result.error("COVER", "frame tidak kebaca", null); return }
            if (matrix != null && matrix.size == 16) {
                bmp = applyColorMatrix(bmp, matrix)
            }
            File(outPath).parentFile?.mkdirs()
            FileOutputStream(outPath).use { bmp.compress(Bitmap.CompressFormat.JPEG, 92, it) }
            result.success(outPath)
        } catch (e: Exception) {
            result.error("COVER_ERR", e.message, null)
        }
    }

    // Matriks 4x4 (row-major, dari Dart) -> ColorMatrix 4x5 (kolom offset = 0)
    private fun applyColorMatrix(src: Bitmap, m: List<Double>): Bitmap {
        val a = FloatArray(20)
        for (row in 0..3) {
            for (col in 0..3) a[row * 5 + col] = m[row * 4 + col].toFloat()
            a[row * 5 + 4] = 0f
        }
        val paint = Paint().apply { colorFilter = ColorMatrixColorFilter(ColorMatrix(a)) }
        val out = Bitmap.createBitmap(src.width, src.height, src.config ?: Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(src, 0f, 0f, paint)
        return out
    }

    // Trim + re-encode ringan (skala tinggi `height`, H264+AAC) + look preset.
    // result.success dipanggil dari listener SAAT SELESAI (Dart menunggu + polling progress).
    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        if (transformer != null) { result.error("BUSY", "Masih ada proses video berjalan", null); return }
        val inPath = call.argument<String>("inPath")
        val outPath = call.argument<String>("outPath")
        val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
        val endMs = (call.argument<Number>("endMs") ?: 0).toLong()
        val height = (call.argument<Number>("height") ?: 720).toInt()
        val matrix = call.argument<List<Double>>("matrix")
        if (inPath == null || outPath == null || endMs <= startMs) {
            result.error("ARGS", "argumen trim tidak valid", null); return
        }
        try {
            val clipping = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()
            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(inPath)))
                .setClippingConfiguration(clipping)
                .build()

            val videoEffects = mutableListOf<Effect>()
            videoEffects.add(Presentation.createForHeight(height))
            if (matrix != null && matrix.size == 16) {
                val m = FloatArray(16) { i -> matrix[i].toFloat() }
                videoEffects.add(RgbMatrix { _, _ -> m })
            }

            val edited = EditedMediaItem.Builder(item)
                .setEffects(Effects(emptyList(), videoEffects))
                .build()

            val t = Transformer.Builder(appContext)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        val size = try { File(outPath).length() } catch (_: Exception) { 0L }
                        pendingResult?.success(mapOf("outPath" to outPath, "size" to size))
                        cleanupJob()
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        pendingResult?.error(
                            "TRANSFORM_GAGAL",
                            exportException.message ?: "encode gagal",
                            null
                        )
                        cleanupJob()
                    }
                })
                .build()

            File(outPath).parentFile?.mkdirs()
            transformer = t
            pendingResult = result
            t.start(edited, outPath)
        } catch (e: Exception) {
            cleanupJob()
            result.error("TRANSFORM_ERR", e.message, null)
        }
    }

    // Polling dari Dart (tiap 250-300ms). Wajib main thread (MethodChannel sudah main).
    private fun handleProgress(result: MethodChannel.Result) {
        val t = transformer
        if (t == null) { result.success(mapOf("state" to 0, "progress" to 0)); return }
        try {
            val state = t.getProgress(progressHolder)
            result.success(mapOf("state" to state, "progress" to progressHolder.progress))
        } catch (_: Exception) {
            result.success(mapOf("state" to 0, "progress" to 0))
        }
    }
}
