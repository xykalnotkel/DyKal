
import 'dart:async';
import 'package:flutter/services.dart';

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
}
