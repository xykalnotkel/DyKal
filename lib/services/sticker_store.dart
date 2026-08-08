import 'dart:io';
import 'package:dio/dio.dart';

/// Penyimpanan stiker lokal: Android/media/com.dykal.app/Dykal/Stiker/
class StickerStore {
  static const _pkg = 'com.dykal.app';

  static Future<Directory> dir() async {
    final d = Directory('/storage/emulated/0/Android/media/$_pkg/Dykal/Stiker');
    try {
      if (!await d.exists()) await d.create(recursive: true);
    } catch (_) {}
    return d;
  }

  /// List semua stiker lokal (png/jpg/webp/gif)
  static Future<List<File>> list() async {
    try {
      final d = await dir();
      final files = d.listSync().whereType<File>().where((f) {
        final p = f.path.toLowerCase();
        return p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp') || p.endsWith('.gif');
      }).toList();
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Salin file jadi stiker lokal. return path lokal atau null.
  static Future<String?> add(File src) async {
    try {
      final d = await dir();
      final ext = src.path.split('.').last.toLowerCase();
      final name = 'stiker_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = '${d.path}/$name';
      await src.copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  /// Download dari URL (mis. stiker dari pasangan) ke lokal. return path atau null.
  static Future<String?> addFromUrl(String url) async {
    try {
      final d = await dir();
      final ext = url.toLowerCase().contains('.gif') ? 'gif' : 'png';
      final name = 'stiker_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = '${d.path}/$name';
      await Dio().download(url, dest);
      return dest;
    } catch (_) {
      return null;
    }
  }
}
