import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Presence 4-status (Batch I — permintaan owner):
///  1. "Online · WiFi/data seluler"   -> app kebuka & heartbeat segar
///  2. "Lagi buka TikTok/IG/..."      -> data nyala, app DyKal TERTUTUP, dan
///       device partner membagikan aktivitasnya (opt-in, service native).
///  3. "Data nyala"                   -> heartbeat app mati tapi service
///       partner masih melapor (app DyKal tertutup, internet aktif).
///  4. "Terakhir dilihat ..."         -> benar-benar offline (data mati) —
///       JUJUR, tidak lagi claim online basi selamanya.
///
/// Mekanisme: app foreground menulis `hb` (heartbeat) tiap 45 dtk; pembaca
/// hanya percaya status online bila hb < 120 dtk. Service native menulis
/// `fgs` + `fgApp` tiap 60 dtk walau app tertutup (jika user mengaktifkan).
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const _hbFreshMs = 120 * 1000; // heartbeat dianggap segar < 2 menit
  static const _fgsFreshMs = 150 * 1000; // laporan service segar < 2.5 menit

  Timer? _timer;
  String _net = 'none';
  bool _running = false;

  void setNet(String net) => _net = net;

  /// Mulai heartbeat (panggil saat MainNav aktif / lifecycle resumed).
  void start() {
    if (_running) return;
    _running = true;
    _beat(); // langsung 1x
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _beat());
  }

  /// Lifecycle paused/detached -> status offline jujur.
  Future<void> stop({bool offline = true}) async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    if (offline) await _write({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()});
  }

  Future<void> _beat() async {
    await _write({
      'isOnline': true,
      'hb': FieldValue.serverTimestamp(),
      'net': _net,
    });
  }

  Future<void> _write(Map<String, dynamic> fields) async {
    final uid = AuthService().myId;
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .doc('presence/$uid')
          .set(fields, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  // ---------- Formatter untuk UI ----------
  static int _msOf(dynamic ts) =>
      ts is Timestamp ? ts.millisecondsSinceEpoch : 0;

  /// Kembalikan (teksStatus, isOnline) dari dok presence partner.
  /// [typing]/[rec] ditangani pemanggil (prioritas lebih tinggi).
  static (String, bool) describe(Map<String, dynamic>? data) {
    if (data == null) return ('offline', false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = data['isOnline'] == true;
    final hbMs = _msOf(data['hb']);
    final fgsMs = _msOf(data['fgs']);
    final lastSeen = data['lastSeen'];
    final net = data['net'] as String? ?? 'none';
    final fgApp = data['fgApp'] as String?;

    final hbFresh = online && hbMs > 0 && (now - hbMs) < _hbFreshMs;
    if (hbFresh) {
      final via = net == 'wifi' ? 'WiFi' : (net == 'mobile' ? 'data seluler' : 'online');
      return ('Online · $via', true);
    }
    final fgsFresh = fgsMs > 0 && (now - fgsMs) < _fgsFreshMs;
    if (fgsFresh) {
      if (fgApp != null && fgApp.isNotEmpty) {
        return ('Lagi buka $fgApp', false);
      }
      return ('Data nyala, tidak sedang di app', false);
    }
    if (lastSeen is Timestamp) {
      final dt = lastSeen.toDate();
      return ('Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}', false);
    }
    if (hbMs > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(hbMs);
      return ('Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}', false);
    }
    return ('offline', false);
  }
}
