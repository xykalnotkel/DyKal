import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache pemetaan URL media (foto/video) -> file lokal, pasangan dari
/// [VoiceCache] yang khusus voice note. Tujuannya: OFFLINE-FIRST ala WA —
/// media yang sudah pernah terunduh otomatis bisa dibuka walau internet mati.
///
/// Sumber path: MediaSaver.save() saat pesan media masuk / terkirim.
/// Pembaca: MessageBubble (tampilkan Image.file jika ada, fallback CDN).
class MediaCache {
  static const _key = 'media_cache_map';

  static Future<Map<String, String>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, String> map) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(map));
  }

  /// Simpan mapping URL -> path file lokal.
  static Future<void> put(String url, String path) async {
    final map = await _load();
    map[url] = path;
    await _save(map);
  }

  /// Ambil path lokal untuk URL. Mengembalikan null jika belum ada ATAU
  /// filenya sudah terhapus dari storage (mapping usang dibersihkan sekalian).
  static Future<String?> get(String url) async {
    final map = await _load();
    final path = map[url];
    if (path == null) return null;
    try {
      if (await File(path).exists()) return path;
      // File hilang (user bersih-bersih) -> cabut mapping biar tidak nyangkut.
      map.remove(url);
      await _save(map);
    } catch (_) {}
    return null;
  }
}
