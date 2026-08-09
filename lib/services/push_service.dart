import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Kirim push ke device pasangan via Cloudflare Worker (FCM HTTP v1).
/// Berfungsi walau app pasangan di-kill (background push) — TANPA Blaze.
/// Aktif setelah kamu deploy Worker & mengisi workerUrl di bawah.
class PushService {
  /// Ganti dengan URL Worker kamu (lihat cloudflare/README.md).
  static const String workerUrl = 'https://dykal.akuntiktok76y.workers.dev';

  static bool get _enabled =>
      workerUrl.contains('workers.dev') && !workerUrl.contains('example');

  /// Panggil saat: kirim chat baru / mulai panggilan.
  static Future<void> notifyPartner({
    required String title,
    required String body,
    String type = 'chat',
    String? callerName,
    String? callType,
  }) async {
    if (!_enabled) return;
    final partnerId = AuthService().partnerId ?? '';
    if (partnerId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.doc('users/$partnerId').get();
      final data = snap.data();
      final token = data?['fcmToken'] as String?;
      if (token == null || token.isEmpty) return;
      // FIX #12: hormati preferensi notifikasi pasangan (kalau dimatikan, skip push)
      final prefs = data?['notifPrefs'] as Map<String, dynamic>?;
      final key = type == 'call' ? 'call' : (type == 'letter' ? 'letter' : 'chat');
      if (prefs != null && prefs[key] == false) return;
      await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'type': type,
          'data': {
            'coupleId': AuthService().coupleId ?? '',
            'type': type,
            if (callerName != null) 'callerName': callerName,
            if (callType != null) 'callType': callType,
          },
        }),
      );
    } catch (_) {}
  }
}
