import 'package:flutter/services.dart';

/// Ringtone picker native via MethodChannel -> RingtoneManager (Android).
/// type: 1 = ringtone (telepon), 2 = notification, 4 = alarm
class RingtoneService {
  static const _ch = MethodChannel('dykal/ringtone');

  /// Ambil daftar nada sistem. type: 1=telepon, 2=notifikasi, 4=alarm
  static Future<List<Map<String, dynamic>>> getRingtones({int type = 2}) async {
    try {
      final res = await _ch.invokeMethod('getRingtones', {'type': type});
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> play(String uri) async {
    try { await _ch.invokeMethod('play', {'uri': uri}); } catch (_) {}
  }

  static Future<void> playDefaultRingtone() async {
    try { await _ch.invokeMethod('playDefaultRingtone'); } catch (_) {}
  }

  static Future<void> playDefaultNotification() async {
    try { await _ch.invokeMethod('playDefaultNotification'); } catch (_) {}
  }

  static Future<void> vibrateCall() async {
    try { await _ch.invokeMethod('vibrateCall'); } catch (_) {}
  }

  static Future<void> stopVibrate() async {
    try { await _ch.invokeMethod('stopVibrate'); } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
      await _ch.invokeMethod('stopVibrate');
    } catch (_) {}
  }
}
