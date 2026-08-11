package com.dykal.app

import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val RINGTONE_CHANNEL = "dykal/ringtone"
    private val FLOATING_CHANNEL = "com.dykal.app/floating"
    private val INSTALLER_CHANNEL = "dykal/installer"
    private var currentRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ringtone Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRingtones" -> {
                        val type = call.argument<Int>("type") ?: RingtoneManager.TYPE_NOTIFICATION
                        try {
                            val rm = RingtoneManager(this)
                            rm.setType(type)
                            val cursor = rm.cursor
                            val titleIdx = cursor.getColumnIndex("title")
                            val list = mutableListOf<Map<String, String>>()
                            if (cursor.moveToFirst()) {
                                do {
                                    val title = if (titleIdx >= 0) cursor.getString(titleIdx) ?: "" else ""
                                    val uri = rm.getRingtoneUri(cursor.position).toString()
                                    list.add(mapOf("title" to title, "uri" to uri))
                                } while (cursor.moveToNext())
                            }
                            cursor.close()
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("RINGTONE_ERR", e.message, null)
                        }
                    }
                    "play" -> {
                        try {
                            val uri = call.argument<String>("uri")
                            currentRingtone?.stop()
                            if (uri != null) {
                                currentRingtone = RingtoneManager.getRingtone(this, Uri.parse(uri))
                                currentRingtone?.play()
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("PLAY_ERR", e.message, null)
                        }
                    }
                    "stop" -> {
                        currentRingtone?.stop()
                        currentRingtone = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Floating Service Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(Settings.canDrawOverlays(this))
                        } else {
                            result.success(true)
                        }
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "showChatBubble" -> {
                        val intent = Intent(this, FloatingChatService::class.java)
                        startService(intent)
                        result.success(null)
                    }
                    "hideBubble" -> {
                        val intent = Intent(this, FloatingChatService::class.java)
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // APK Installer Handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                // Updater in-app: deteksi ABI device supaya APK yang diunduh cocok
                // (DyKal-arm64.apk untuk 64-bit, DyKal-armeabi-v7a.apk untuk 32-bit).
                // Urutan SUPPORTED_ABIS = preferensi sistem ([0] = ABI utama).
                if (call.method == "getSupportedAbis") {
                    result.success(Build.SUPPORTED_ABIS.toList())
                    return@setMethodCallHandler
                }
                if (call.method == "installApk") {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.fileprovider",
                                    file
                                )
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File APK tidak ditemukan", null)
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_ERR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Path kosong", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        currentRingtone?.stop()
        super.onDestroy()
    }
}
