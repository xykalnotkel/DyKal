package com.dykal.app

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

/// BATCH I (opt-in owner): service foreground ringan yang melaporkan apa yang
/// sedang dibuka user ("Lagi buka TikTok") + memberi sinyal "data nyala tapi
/// app DyKal tertutup". Poll UsageStats tiap 60 dtk, tulis presence/{uid}.
/// NONAKTIF default; privasi: hanya NAMA RAMAH app (bukan konten), hanya saat
/// toggle nyala, nama app di-map di sini (tak pernah membaca detail layar).
class ActivityShareService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val intervalMs = 60_000L
    private var running = false

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            report()
            handler.postDelayed(this, intervalMs)
        }
    }

    private val friendlyNames = mapOf(
        "com.zhiliaoapp.musically" to "TikTok",
        "com.ss.android.ugc.trill" to "TikTok",
        "com.instagram.android" to "Instagram",
        "com.whatsapp" to "WhatsApp",
        "com.google.android.youtube" to "YouTube",
        "com.spotify.music" to "Spotify",
        "com.android.chrome" to "Chrome",
        "org.telegram.messenger" to "Telegram",
        "com.twitter.android" to "X (Twitter)",
        "com.facebook.katana" to "Facebook",
        "com.facebook.lite" to "Facebook Lite",
        "com.mobile.legends" to "Mobile Legends",
        "com.dts.freefireth" to "Free Fire",
        "com.tencent.ig" to "PUBG Mobile",
        "com.garena.gaslite" to "Free Fire Lite",
        "com.vanced.android.youtube" to "YouTube",
        "com.google.android.gm" to "Gmail",
        "com.google.android.apps.maps" to "Maps",
        "com.shopee.id" to "Shopee",
        "com.tokopedia.tkpd" to "Tokopedia",
        "com.blibli.mobile" to "Blibli",
        "id.co.gojek" to "Gojek",
        "com.grabtaxi.passenger" to "Grab",
        "com.netflix.mediaclient" to "Netflix",
        "com.vidio.android" to "Vidio",
        "com.wetv.vip" to "WeTV",
        "com.bCAPE.app.id" to "Vidio",
        "com.google.android.apps.photos" to "Poto (Galeri)",
        "com.sec.android.app.camera" to "Kamera",
        "com.android.settings" to "Pengaturan",
        "com.miui.home" to "Beranda",
        "com.android.launcher3" to "Beranda",
        "com.sec.android.app.launcher" to "Beranda"
    )

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
        }
        startForeground(NOTIF_ID, buildNotif())
        if (!running) {
            running = true
            handler.post(tick)
        }
        return START_STICKY
    }

    private fun report() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val top = currentTopApp()
        // Tulis fgs (laporan service segar) + fgApp bila ada yg terdeteksi.
        // fgApp null DIHAPUS dari doc agar status tak basi (FieldValue.delete).
        val fields = hashMapOf<String, Any>(
            "fgs" to com.google.firebase.firestore.FieldValue.serverTimestamp()
        )
        if (top != null && top != packageName) {
            fields["fgApp"] = friendlyOf(top)
        } else {
            fields["fgApp"] = com.google.firebase.firestore.FieldValue.delete()
        }
        try {
            FirebaseFirestore.getInstance()
                .document("presence/$uid")
                .set(fields, SetOptions.merge())
        } catch (_: Exception) {}
    }

    private fun friendlyOf(pkg: String): String {
        friendlyNames[pkg]?.let { return it }
        return try {
            val pm = packageManager
            val ai = pm.getApplicationInfo(pkg, 0)
            pm.getApplicationLabel(ai).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            pkg.substringAfterLast('.').replaceFirstChar { it.uppercase() }
        }
    }

    private fun currentTopApp(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - 90_000
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, begin, end)
            var best: android.app.usage.UsageStats? = null
            for (s in stats) {
                if (best == null || s.lastTimeUsed > best!!.lastTimeUsed) best = s
            }
            best?.packageName
        } catch (e: Exception) { null }
    }

    private fun buildNotif(): Notification {
        val chId = "dykal_activity_share"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(chId, "DyKal Aktivitas Perangkat", NotificationManager.IMPORTANCE_MIN)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, ActivityShareService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, chId) else Notification.Builder(this)
        return b.setContentTitle("DyKal membagikan aktivitas perangkat")
            .setContentText("Pasanganmu bisa melihat aplikasi yang sedang kamu buka.")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Matikan", stop).build())
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_STOP = "com.dykal.app.ACTIVITY_SHARE_STOP"
        const val NOTIF_ID = 88410

        fun hasUsagePermission(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= 29) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(), context.packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(), context.packageName)
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }
    }
}
