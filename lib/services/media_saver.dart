import 'dart:io';
import 'package:dio/dio.dart';

/// Simpan media (foto/voice/video) ke folder eksternal app,
/// seperti WhatsApp: Android/media/com.dykal.app/Dykal/Media/{foto,audio,video,stiker}
class MediaSaver {
  static const _pkg = 'com.dykal.app';

  /// Buat & kembalikan path folder tujuan
  static Future<String> _dir(String type) async {
    final root = Directory('/storage/emulated/0/Android/media/$_pkg/Dykal/Media/$type');
    try {
      if (!await root.exists()) await root.create(recursive: true);
      return root.path;
    } catch (_) {
      // fallback: folder app-specific
      final fb = Directory('/storage/emulated/0/Android/data/$_pkg/files/Dykal/Media/$type');
      if (!await fb.exists()) await fb.create(recursive: true);
      return fb.path;
    }
  }

  /// Download dari url & simpan. return path atau null.
  static Future<String?> save(String url, {String type = 'foto'}) async {
    try {
      final dir = await _dir(type);
      final ext = type == 'audio' ? 'm4a' : (type == 'video' ? 'mp4' : 'jpg');
      final name = 'dykal_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$dir/$name';
      await Dio().download(url, path);
      return path;
    } catch (e) {
      return null;
    }
  }
}
