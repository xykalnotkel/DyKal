import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Kirim push ke device pasangan via Cloudflare Worker (FCM HTTP v1).
/// Berfungsi walau app pasangan di-kill (background push) — TANPA Blaze.
/// Aktif setelah kamu deploy Worker & mengisi workerUrl di bawah.
class PushService {
  /// Custom domain resmi (domain XYSTUDIO, TLS otomatis Cloudflare).
  /// Route lama https://dykal.akuntiktok76y.workers.dev TETAP HIDUP di sisi
  /// Cloudflare demi APK versi lama — jangan pernah minta dimatikan.
  static const String workerUrl = 'https://push.xystudio.my.id';

  /// Shared key anti-abuse untuk Worker.
  /// Disuntik CI saat build via --dart-define=DYKAL_PUSH_KEY=... (nilainya = GitHub
  /// secret DYKAL_PUSH_KEY = secret worker Cloudflare). SENGAJA tidak di-hardcode
  /// karena repo ini publik. Build manual/lokal tanpa dart-define -> kosong.
  static const String workerKey = String.fromEnvironment('DYKAL_PUSH_KEY');

  // Jangan cek substring 'workers.dev' lagi: URL resmi sekarang custom domain.
  // Cukup pastikan bukan placeholder contoh dan pakai https.
  static bool get _enabled =>
      workerUrl.startsWith('https://') && !workerUrl.contains('example');

  static String? _cachedToken;
  static bool? _cachedV2;
  static Map<String, dynamic>? _cachedPrefs;
  static DateTime? _cacheFetchedAt;

  static void invalidateCache() => _cacheFetchedAt = null;

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
      final me = AuthService();
      String? token = _cachedToken;
      bool dataOnly = _cachedV2 ?? false;
      Map<String, dynamic>? prefs = _cachedPrefs;

      final now = DateTime.now();
      if (token == null || _cacheFetchedAt == null || now.difference(_cacheFetchedAt!).inMinutes > 10) {
        final snap = await FirebaseFirestore.instance.doc('users/$partnerId').get();
        final data = snap.data();
        token = data?['fcmToken'] as String?;
        dataOnly = data?['notifCap'] == 'v2';
        prefs = data?['notifPrefs'] as Map<String, dynamic>?;
        if (token != null) {
          _cachedToken = token;
          _cachedV2 = dataOnly;
          _cachedPrefs = prefs;
          _cacheFetchedAt = now;
        }
      }

      if (token == null || token.isEmpty) return;
      // FIX #12: hormati preferensi notifikasi pasangan (kalau dimatikan, skip push)
      final key = type.startsWith('call') ? 'call' : (type == 'letter' ? 'letter' : 'chat');
      if (prefs != null && prefs[key] == false) return;
      await http.post(
        Uri.parse(workerUrl),
        headers: {
          'Content-Type': 'application/json',
          if (workerKey.isNotEmpty) 'x-dykal-key': workerKey,
        },
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'type': type,
          if (dataOnly) 'dataOnly': true,
          'data': {
            'coupleId': me.coupleId ?? '',
            'type': type,
            // Spek v2: renderer notif butuh identitas pengirim langsung di
            // payload — nama & avatar untuk MessagingStyle ala WhatsApp.
            'senderName': me.myName,
            'senderAvatar': me.myPhotoUrl ?? '',
            'messageBody': body,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            if (callerName != null) 'callerName': callerName,
            if (callType != null) 'callType': callType,
          },
        }),
      );
    } catch (_) {}
  }
}
