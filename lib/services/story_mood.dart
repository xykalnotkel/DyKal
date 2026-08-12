import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

/// Mood cerita dari FOTO album (Batch I — "story bisa deteksi suasana").
/// Analisis LOKAL (tanpa server/ML berat): decode thumbnail 32x32, lalu ukur
/// kecerahan (luma), kejenuhan warna (saturation), dan kehangatan (r-b).
///
/// Aturan (heuristik transparan):
///  cerah + colorful            -> 'ceria'  (musik upbeat)
///  hangat + cukup colorful     -> 'romantis'
///  gelap / pudar (low sat)     -> 'sendu'  (musik melow)
///  sisanya                     -> 'tenang' (akustik/lofi)
enum StoryMood { ceria, romantis, sendu, tenang }

class StoryMoodAnalyzer {
  static Future<StoryMood> analyzeBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return StoryMood.tenang;
      final px = data.buffer.asUint8List();
      double lum = 0, sat = 0, warm = 0;
      final n = px.length ~/ 4;
      for (var i = 0; i < px.length; i += 4) {
        final r = px[i] / 255.0, g = px[i + 1] / 255.0, b = px[i + 2] / 255.0;
        lum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
        final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        sat += (mx - mn);
        warm += (r - b);
      }
      lum /= n; sat /= n; warm /= n;
      if (lum > 0.60 && sat > 0.28) return StoryMood.ceria;
      if (warm > 0.10 && sat > 0.18) return StoryMood.romantis;
      if (lum < 0.34 || sat < 0.14) return StoryMood.sendu;
      return StoryMood.tenang;
    } catch (_) {
      return StoryMood.tenang;
    }
  }

  /// Tebak mood dari nama file musik (heuristik kasar saat user menambahkan).
  static StoryMood guessFromName(String fileName) {
    final f = fileName.toLowerCase();
    if (RegExp(r'sad|sedih|galau|mellow|slow|hurt|patah|rindu|nangis').hasMatch(f)) return StoryMood.sendu;
    if (RegExp(r'happy|ceria|senang|funkot|dance|party|upbeat|ceria').hasMatch(f)) return StoryMood.ceria;
    if (RegExp(r'love|cinta|sayang|romantis|romance|heart').hasMatch(f)) return StoryMood.romantis;
    return StoryMood.tenang;
  }

  static const labels = {
    StoryMood.ceria: 'Ceria',
    StoryMood.romantis: 'Romantis',
    StoryMood.sendu: 'Sendu',
    StoryMood.tenang: 'Tenang',
  };
}

/// Peta path-file -> mood, agar player cerita bisa memilih lagu senada.
class StoryMoodStore {
  static const _key = 'story_audio_moods';

  static Future<Map<String, StoryMood>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key) ?? '{}';
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m.map((k, v) => MapEntry(k, StoryMood.values.firstWhere(
          (e) => e.name == v, orElse: () => StoryMood.tenang)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<String, StoryMood> map) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(map.map((k, v) => MapEntry(k, v.name))));
    } catch (_) {}
  }
}
