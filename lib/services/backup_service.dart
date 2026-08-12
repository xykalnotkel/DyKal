import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'media_saver.dart';

/// BATCH M — Ekspor data & hapus akun.
///
/// Prinsip jujur yang dipegang:
///  1. Ekspor = JSON metadata TEKS (profil, pesan, surat, daftar media+URL).
///     File medianya TIDAK ikut (ukurannya GB-an di cloud) — yang diekspor
///     arsip yang bisa dibaca manusia. Bukan restore penuh.
///  2. Hapus akun = re-auth (sandi) -> hapus dok milikmu -> hapus Auth.
///     Konsekuensi ditulis GAMBLANG ke user: kunci E2E di HP ini ikut musnah,
///     artinya semua media terenkripsi (/dykal/e2e/) tak bisa dibuka lagi
///     oleh SIAPA PUN — itu memang tujuan E2E. Riwayat chat di HP pasangan
///     tetap ada (datanya dia).
class BackupService {
  /// Sanitizer rekursif: ubah tipe Firestore jadi aman-JSON.
  static Object? _safe(Object? v) {
    if (v == null || v is num || v is String || v is bool) return v;
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
    if (v is Map) {
      return v.map((k, val) => MapEntry('$k', _safe(val)));
    }
    if (v is Iterable) return v.map(_safe).toList();
    return v.toString();
  }

  /// Ekspor JSON -> path file lokal (folder dokumen gaya WA: Android/media).
  /// Lempar Exception dengan pesan manusia saat gagal.
  static Future<String> exportData() async {
    final uid = AuthService().myId;
    if (uid.isEmpty) throw Exception('Kamu belum masuk — login dulu.');
    final fs = FirebaseFirestore.instance;

    final out = <String, dynamic>{
      'app': 'DyKal',
      'skema': 1,
      'dieksporPada': DateTime.now().toIso8601String(),
      'catatan':
          'Arsip teks (profil, pesan, surat, daftar media + URL-nya). File foto/video/audio '
              'TIDAK disertakan — tetap di cloud/HP. Media terenkripsi (/dykal/e2e/) hanya '
              'bisa dibuka dari HP pasangan selama kunci E2E masih ada.',
    };

    // Profilku
    try {
      final me = await fs.doc('users/$uid').get();
      out['profil'] = _safe(me.data());
    } catch (_) {
      out['profil'] = {'error': 'gagal memuat profil'};
    }

    final coupleId = AuthService().coupleId;
    out['coupleId'] = coupleId;

    // Pesan (2000 terbaru — cukup untuk arsip, query tetap ringan)
    if (coupleId != null && coupleId.isNotEmpty) {
      try {
        final qs = await fs
            .collection('chats/$coupleId/messages')
            .orderBy('createdAt', descending: true)
            .limit(2000)
            .get();
        out['pesan'] = qs.docs.map((d) => _safe(d.data())).toList();
      } catch (_) {
        out['pesan'] = {'error': 'gagal memuat pesan'};
      }
      // Surat cinta
      try {
        final ls = await fs.collection('couples/$coupleId/letters').limit(500).get();
        out['surat'] = ls.docs.map((d) => _safe(d.data())).toList();
      } catch (_) {
        out['surat'] = {'error': 'gagal memuat surat'};
      }
      // Album + metadata foto (bukan file)
      try {
        final as = await fs.collection('couples/$coupleId/albums').get();
        final albums = <Map<String, dynamic>>[];
        for (final a in as.docs) {
          final photos = await fs
              .collection('couples/$coupleId/albums/${a.id}/photos')
              .limit(500)
              .get();
          albums.add({
            ...(_safe(a.data()) as Map),
            'foto': photos.docs.map((d) => _safe(d.data())).toList(),
          });
        }
        out['album'] = albums;
      } catch (_) {
        out['album'] = {'error': 'gagal memuat album'};
      }
    } else {
      out['catatan'] = '${out['catatan']} (Belum punya pasangan — hanya profil yang diekspor.)';
    }

    final dir = await MediaSaver.getDirectory(category: 'documents');
    final n = DateTime.now();
    final stamp = '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_'
        '${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
    final f = File('$dir/dykal_backup_$stamp.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(out));
    return f.path;
  }

  /// Hapus akun permanen. [password] untuk re-auth (wajib oleh Firebase).
  /// Lempar Exception berbahasa manusia saat gagal.
  static Future<void> deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw Exception('Sesi tidak valid — keluar lalu masuk lagi dulu.');
    }
    final uid = user.uid;

    // 1) Re-auth (kalau sandi salah -> berhenti di sini, belum ada yang dihapus)
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Sandi salah — akun belum dihapus apa pun.'
            : 'Verifikasi gagal (${e.code}). Akun belum dihapus.',
      );
    }

    // 2) Bersihkan dok milikku (best-effort: kegagalan sebagian tidak membatalkan
    //    penghapusan akun — lebih baik akun hilang daripada setengah terkunci).
    final fs = FirebaseFirestore.instance;
    try {
      final me = await fs.doc('users/$uid').get();
      final uname = me.data()?['username'] as String?;
      if (uname != null && uname.isNotEmpty) {
        await fs.doc('usernames/$uname').delete();
      }
    } catch (_) {}
    try {
      await fs.doc('presence/$uid').delete();
    } catch (_) {}
    try {
      await fs.doc('users/$uid').delete();
    } catch (_) {}

    // 3) Musnahkan kunci E2E di HP ini — ciphertext couple tak bisa dibuka lagi.
    try {
      await const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ).deleteAll();
    } catch (_) {}

    // 4) Baru terakhir: hapus akun Auth.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception('Dok terhapus, tapi akun Auth gagal dihapus (${e.code}) — coba lagi.');
    }
  }
}
