import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache pemetaan URL voice note -> file lokal.
/// Voice note yang diterima otomatis disimpan oleh MediaSaver ke
/// Android/media/com.dykal.app/Dykal/Media/Dykal Audio/Dykal Voice Notes/.
/// Cache ini memungkinkan playback OFFLINE (tanpa internet) lewat file lokal.
class VoiceCache {
  static const _key = 'voice_cache_map';

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

  /// Ambil path lokal untuk URL (null jika belum pernah disimpan).
  static Future<String?> get(String url) async {
    final map = await _load();
    return map[url];
  }
}
