
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk floating bubble (chat overlay + video call overlay).
/// Butuh permission SYSTEM_ALERT_WINDOW (sudah di manifest).
class FloatingService {
  static const _platform = MethodChannel('com.dykal.app/floating');

  /// Cek apakah punya izin overlay
  static Future<bool> hasOverlayPermission() async {
    try {
      return await _platform.invokeMethod('hasPermission');
    } catch (_) {
      return false;
    }
  }

  /// Minta izin overlay (buka Settings > Display over other apps)
  static Future<void> requestOverlayPermission() async {
    try {
      await _platform.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Tampilkan floating chat bubble
  static Future<void> showChatBubble({String? coupleId}) async {
    try {
      await _platform.invokeMethod('showChatBubble', {'coupleId': coupleId ?? ''});
    } catch (_) {}
  }

  /// Sembunyikan floating bubble
  static Future<void> hideBubble() async {
    try {
      await _platform.invokeMethod('hideBubble');
    } catch (_) {}
  }

  /// Rute tertunda dari menu bubble ("Buka Chat") — ditulis native ke
  /// FlutterSharedPreferences ('pending_route'), dibaca & dibersihkan
  /// sekali saat app resume (mis. dari MainNav).
  static Future<String?> consumePendingRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString('pending_route');
      if (route != null) {
        await prefs.remove('pending_route');
        return route;
      }
    } catch (_) {}
    return null;
  }
}
