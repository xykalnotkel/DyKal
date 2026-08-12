package com.dykal.app

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs

/**
 * Floating chat bubble (chat head) ala WhatsApp.
 * - Butuh izin SYSTEM_ALERT_WINDOW; dicek sebelum addView.
 * - FIX (laporan owner): dulu drag & tap tidak dibedakan -> lepas drag selalu
 *   membuka app ("dipencet malah masuk aplikasi") dan bubble tanpa ukuran fix
 *   jadi kecil/kabur. Sekarang: drag = geser saja (+snap ke tepi terdekat),
 *   TAP (gerakan < ambang) = buka app, TAHAN LAMA = tutup bubble.
 */
class FloatingChatService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var menuView: View? = null // panel menu tap-bubble

    private val density by lazy { resources.displayMetrics.density }
    private fun dp(v: Int) = (v * density).toInt()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val size = dp(56)
        val container = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF6B8A"))
            }
            elevation = dp(4).toFloat()
        }
        container.addView(
            ImageView(this).apply { setImageResource(R.drawable.ic_chat_bubble) },
            FrameLayout.LayoutParams(dp(30), dp(30), Gravity.CENTER)
        )

        val params = WindowManager.LayoutParams(
            size, size,
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
            windowManager?.addView(container, params)
            floatingView = container
        } catch (e: Exception) {
            stopSelf()
            return
        }

        val touchSlop = dp(8) // gerakan di bawah ini dianggap tap, bukan drag
        var downRawX = 0f
        var downRawY = 0f
        var moved = false
        var longPressed = false

        val longPress = Runnable {
            longPressed = true
            // Tahan lama = tutup bubble (cara satu-satunya mematikan selain toggle di Settings)
            stopSelf()
        }

        container.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    moved = false
                    longPressed = false
                    v.postDelayed(longPress, 600)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (!moved && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        moved = true
                        v.removeCallbacks(longPress) // dibatalkan: ini drag, bukan tahan
                        hideMenu() // bubble geser -> menu ikut hilang
                    }
                    if (moved) {
                        params.x = event.rawX.toInt() - container.width / 2
                        params.y = event.rawY.toInt() - container.height / 2
                        windowManager?.updateViewLayout(container, params)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    v.removeCallbacks(longPress)
                    if (longPressed) return@setOnTouchListener true
                    if (!moved) {
                        // TAP murni -> toggle MENU bubble (Batch: permintaan owner).
                        // Bukan langsung buka app lagi.
                        toggleMenu(params)
                    } else {
                        // Habis drag -> snap ke tepi kiri/kanan terdekat (rasa WA)
                        val screenW = resources.displayMetrics.widthPixels
                        val targetX = if (params.x + container.width / 2 < screenW / 2) dp(8) else screenW - container.width - dp(8)
                        params.x = targetX
                        windowManager?.updateViewLayout(container, params)
                    }
                }
                MotionEvent.ACTION_CANCEL -> v.removeCallbacks(longPress)
            }
            true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingView?.let { windowManager?.removeView(it) }
        floatingView = null
        hideMenu()
    }

    // ---------- MENU BUBBLE (tap = buka/tutup) ----------

    private fun toggleMenu(bubbleParams: WindowManager.LayoutParams) {
        if (menuView != null) { hideMenu(); return }
        showMenu(bubbleParams)
    }

    private fun hideMenu() {
        menuView?.let { try { windowManager?.removeView(it) } catch (_: Exception) {} }
        menuView = null
    }

    /// Menu kecil di samping bubble: Buka Chat / Buka App / Tutup Bubble.
    /// Sengaja TextView label (bukan ikon) — tegas & tanpa dependensi drawable.
    private fun showMenu(bubbleParams: WindowManager.LayoutParams) {
        val wm = windowManager ?: return
        val panel = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#EE1F1A22")) // gelap sesuai tema
                setStroke(dp(1), Color.parseColor("#33FFFFFF"))
            }
            elevation = dp(6).toFloat()
            setPadding(dp(6), dp(6), dp(6), dp(6))
        }

        fun item(label: String, color: Int, onClick: () -> Unit): View {
            val tv = android.widget.TextView(this).apply {
                text = label
                setTextColor(color)
                textSize = 13f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                val pad = dp(12)
                setPadding(pad, dp(8), pad, dp(8))
            }
            tv.setOnClickListener { onClick() }
            return tv
        }

        // 1. BUKA CHAT: buka app dengan jalan tikus rute chat.
        panel.addView(item("Buka Chat", Color.parseColor("#FF6B8A")) {
            launchApp(route = "chat")
            hideMenu()
        })
        // 2. BUKA APLIKASI biasa (beranda).
        panel.addView(item("Buka Aplikasi", Color.WHITE) {
            launchApp(route = null)
            hideMenu()
        })
        // 3. TUTUP BUBBLE.
        panel.addView(item("Tutup Bubble", Color.parseColor("#FF8A80")) {
            hideMenu()
            stopSelf()
        })

        val mp = WindowManager.LayoutParams(
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
            // Panel duduk tepat di bawah bubble.
            x = bubbleParams.x
            y = bubbleParams.y + dp(64)
        }
        try {
            wm.addView(panel, mp)
            menuView = panel
        } catch (_: Exception) {}
    }

    /// Buka MainActivity; rute "chat" dititipkan lewat intent extra dan
    /// dipersist ke shared prefs (Flutter membaca & membersihkan saat resume).
    private fun launchApp(route: String?) {
        if (route != null) {
            getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                .edit().putString("flutter.pending_route", route).apply()
        }
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
    }
}
