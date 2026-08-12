import 'package:flutter/services.dart';

/// BATCH J — Live Photo Fase 1 (jembatan ke LivePhotoTool.kt / Media3 Transformer).
/// Semua berat di native; file ini cuma kontrak channel + generator matriks preset.
///
/// Matriks warna: 4x4 row-major (r,g,b,a). Sisi Kotlin memakainya dua arah:
///  - video : RgbMatrix (media3-effect)
///  - cover : android.graphics.ColorMatrix (baris sama + kolom offset 0)
/// Karena sumber matriksnya SATU (dari sini), cover & klip dijamin satu rasa.
class LivePhotoJobProgress {
  // media3 1.4.1 (diverifikasi dari source tag): NOT_STARTED=0,
  // WAITING_FOR_AVAILABILITY=1, AVAILABLE=2, UNAVAILABLE=3.
  final int state;
  final int progress; // 0..100 (valid saat state == AVAILABLE)
  const LivePhotoJobProgress(this.state, this.progress);
  bool get available => state == 2;
}

class LivePhotoTool {
  static const MethodChannel _ch = MethodChannel('dykal/livephoto');

  /// Info video sumber: {durMs, width, height}
  static Future<Map<String, dynamic>> probe(String path) async {
    final r = await _ch.invokeMethod<Map>('probe', {'path': path});
    return (r ?? const {}).map((k, v) => MapEntry('$k', v));
  }

  /// Render 1 frame cover (+matriks preset) -> path JPEG. timeUs dalam mikrodetik.
  static Future<String> cover({
    required String path,
    required int timeUs,
    required String outPath,
    List<double>? matrix,
  }) async {
    final r = await _ch.invokeMethod<String>('cover', {
      'path': path,
      'timeUs': timeUs,
      'outPath': outPath,
      'matrix': matrix,
    });
    return r ?? outPath;
  }

  /// Trim [startMs..endMs], skala tinggi [height] (jaga rasio), oles [matrix].
  /// Future selesai SAAT proses tuntas -> {outPath, size}. Lempar PlatformException saat gagal.
  static Future<Map<String, dynamic>> start({
    required String inPath,
    required String outPath,
    required int startMs,
    required int endMs,
    int height = 720,
    List<double>? matrix,
  }) async {
    final r = await _ch.invokeMethod<Map>('start', {
      'inPath': inPath,
      'outPath': outPath,
      'startMs': startMs,
      'endMs': endMs,
      'height': height,
      'matrix': matrix,
    });
    return (r ?? const {}).map((k, v) => MapEntry('$k', v));
  }

  static Future<LivePhotoJobProgress> progress() async {
    try {
      final r = await _ch.invokeMethod<Map>('progress');
      final m = (r ?? const {}).map((k, v) => MapEntry('$k', v));
      final s = m['state'] is num ? (m['state'] as num).toInt() : 0;
      final p = m['progress'] is num ? (m['progress'] as num).toInt() : 0;
      return LivePhotoJobProgress(s, p);
    } catch (_) {
      return const LivePhotoJobProgress(0, 0);
    }
  }

  static Future<void> cancel() async {
    try {
      await _ch.invokeMethod('cancel');
    } catch (_) {}
  }
}

/// Preset look "ala Fomz" — 100% on-device lewat matriks 4x4.
class LivePhotoPreset {
  final String id;
  final String label;
  final List<double>? matrix; // null = asli (tanpa olesan)
  const LivePhotoPreset(this.id, this.label, this.matrix);

  static const List<LivePhotoPreset> all = [
    LivePhotoPreset('asli', 'Asli', null),
    LivePhotoPreset('hangat', 'Hangat', _hangat),
    LivePhotoPreset('ccd', 'CCD 2000an', _ccd),
    LivePhotoPreset('sepia', 'Sepia', _sepia),
    LivePhotoPreset('dingin', 'Dingin', _dingin),
    LivePhotoPreset('pudar', 'Hitam Putih Pudar', _bw),
  ];

  // ---- bangunan dasar (s = saturasi; rumus luma ala ColorMatrix) ----
  static List<double> _identity() => const [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ];

  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(16, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[r * 4 + k] * b[k * 4 + c];
        }
        out[r * 4 + c] = sum;
      }
    }
    return out;
  }

  static List<double> _scale(double r, double g, double b) => [
        r, 0, 0, 0,
        0, g, 0, 0,
        0, 0, b, 0,
        0, 0, 0, 1,
      ];

  static List<double> _sat(double s) {
    const lr = 0.3086, lg = 0.6094, lb = 0.0820;
    final t = 1 - s;
    return [
      lr * t + s, lg * t, lb * t, 0,
      lr * t, lg * t + s, lb * t, 0,
      lr * t, lg * t, lb * t + s, 0,
      0, 0, 0, 1,
    ];
  }

  // ---- racikan preset ----
  static final List<double> _hangat = _mul(_scale(1.08, 1.00, 0.90), _sat(1.05));
  static final List<double> _ccd = _mul(_scale(1.10, 1.02, 0.88), _sat(0.85));
  static final List<double> _sepia = _mul(const [
    0.393, 0.769, 0.189, 0,
    0.349, 0.686, 0.168, 0,
    0.272, 0.534, 0.131, 0,
    0, 0, 0, 1,
  ], _mul(_identity(), _sat(0.9))); // sepia klasik, sedikit dilembutkan
  static final List<double> _dingin = _mul(_scale(0.92, 1.00, 1.10), _sat(0.95));
  static final List<double> _bw = _sat(0.12);
}
