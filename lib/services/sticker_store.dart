import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Penyimpanan stiker lokal: Android/media/com.dykal.app/Dykal/Stiker/
/// Stiker disimpan sbg webp TER-ENKRIPSI (.webp.crypt15) — AES-256-GCM.
class StickerStore {
  static const _pkg = 'com.dykal.app';
  // Kunci 32 byte (AES-256). Dipakai encrypt+decrypt, konsisten.
  static final Key _key = Key.fromUtf8('DyKalStickerKey'.padRight(32, 'x'));

  static Future<Directory> dir() async {
    final d = Directory('/storage/emulated/0/Android/media/$_pkg/Dykal/Stiker');
    try {
      if (!await d.exists()) await d.create(recursive: true);
    } catch (_) {}
    return d;
  }

  /// List stiker lokal (webp.crypt15 + legacy image).
  static Future<List<File>> list() async {
    try {
      final d = await dir();
      return d.listSync().whereType<File>().where((f) {
        final p = f.path.toLowerCase();
        return p.endsWith('.webp.crypt15') || p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp') || p.endsWith('.gif');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Convert ke webp -> enkripsi AES-GCM -> simpan .webp.crypt15. return path lokal atau null.
  static Future<String?> add(File src) async {
    try {
      final d = await dir();
      final tmp = await getTemporaryDirectory();
      final webpPath = '${tmp.path}/stk_${DateTime.now().millisecondsSinceEpoch}.webp';
      final res = await FlutterImageCompress.compressAndGetFile(src.absolute.path, webpPath, quality: 85, format: CompressFormat.webp, minWidth: 512, minHeight: 512);
      final webpBytes = (res != null) ? await File(res.path).readAsBytes() : await src.readAsBytes();
      final encrypted = _encrypt(Uint8List.fromList(webpBytes));
      final name = 'stiker_${DateTime.now().millisecondsSinceEpoch}.webp.crypt15';
      final dest = '${d.path}/$name';
      await File(dest).writeAsBytes(encrypted);
      return dest;
    } catch (_) {
      return null;
    }
  }

  /// Enkripsi AES-256-GCM, prepend IV(12 byte).
  static Uint8List _encrypt(Uint8List data) {
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final enc = encrypter.encryptBytes(data, iv: iv);
    return Uint8List.fromList(iv.bytes + enc.bytes);
  }

  /// Decrypt stiker .webp.crypt15 -> bytes webp (untuk ditampilkan/dikirim). Legacy file -> bytes apa adanya.
  static Future<Uint8List?> readDecrypted(File f) async {
    try {
      if (!f.path.toLowerCase().endsWith('.crypt15')) return await f.readAsBytes();
      final data = await f.readAsBytes();
      final iv = IV(Uint8List.fromList(data.sublist(0, 12)));
      final ct = Encrypted(Uint8List.fromList(data.sublist(12)));
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      return Uint8List.fromList(encrypter.decryptBytes(ct, iv: iv));
    } catch (_) {
      return null;
    }
  }

  /// Decrypt ke file webp sementara (untuk dikirim/upload).
  static Future<File?> tempDecryptedFile(File f) async {
    try {
      final bytes = await readDecrypted(f);
      if (bytes == null) return null;
      final tmp = await getTemporaryDirectory();
      final out = File('${tmp.path}/stk_send_${DateTime.now().millisecondsSinceEpoch}.webp');
      await out.writeAsBytes(bytes);
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Download dari URL (stiker dari pasangan) -> encrypt lokal.
  static Future<String?> addFromUrl(String url) async {
    try {
      final tmp = await getTemporaryDirectory();
      final raw = File('${tmp.path}/stk_dl_${DateTime.now().millisecondsSinceEpoch}');
      await Dio().download(url, raw.path);
      return await add(raw);
    } catch (_) {
      return null;
    }
  }
}
