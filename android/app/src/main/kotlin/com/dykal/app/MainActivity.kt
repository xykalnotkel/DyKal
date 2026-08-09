package com.dykal.app

import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val RINGTONE_CHANNEL = "dykal/ringtone"
    private var currentRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // === Ringtone picker native (RingtoneManager) ===
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRingtones" -> {
                        val type = call.argument<Int>("type") ?: RingtoneManager.TYPE_NOTIFICATION
                        try {
                            val rm = RingtoneManager(this)
                            rm.setType(type)
                            val cursor = rm.cursor
                            val list = mutableListOf<Map<String, String>>()
                            if (cursor.moveToFirst()) {
                                do {
                                    val uri = rm.getRingtoneUri(cursor.position)
                                    var title = ""
                                    try {
                                        val r = RingtoneManager.getRingtone(this, uri)
                                        title = r.getTitle(this)
                                    } catch (_: Exception) {}
                                    list.add(mapOf("title" to title, "uri" to uri.toString()))
                                } while (cursor.moveToNext())
                            }
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
    }

    override fun onDestroy() {
        currentRingtone?.stop()
        super.onDestroy()
    }
}
