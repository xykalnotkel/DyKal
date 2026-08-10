package com.dykal.app

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView

/**
 * Floating chat bubble (chat head) ala WhatsApp.
 * - Butuh izin SYSTEM_ALERT_WINDOW; dicek sebelum addView.
 * - Bisa digeser (drag) dan diketuk untuk membuka aplikasi.
 */
class FloatingChatService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        // Jangan crash diam-diam: tanpa izin overlay, layanan berhenti.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val imageView = ImageView(this).apply {
            setImageResource(R.drawable.ic_chat_bubble)
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 24
            y = 240
        }

        try {
            windowManager?.addView(imageView, params)
            floatingView = imageView
        } catch (e: Exception) {
            stopSelf()
            return
        }

        // Drag bubble
        imageView.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> { }
                MotionEvent.ACTION_MOVE -> {
                    params.x = event.rawX.toInt() - imageView.width / 2
                    params.y = event.rawY.toInt() - imageView.height / 2
                    windowManager?.updateViewLayout(imageView, params)
                }
                MotionEvent.ACTION_UP -> {
                    // Ketuk: buka aplikasi
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    intent?.addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    startActivity(intent)
                }
            }
            true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingView?.let { windowManager?.removeView(it) }
        floatingView = null
    }
}
