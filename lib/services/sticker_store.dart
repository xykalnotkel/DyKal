import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'media_saver.dart';

class StickerStore {
  /// Nama acak panjang ala WhatsApp (.crypt15) — BATCH H (owner): file stiker
  /// terenkripsi TIDAK boleh membawa nama asli/pola stiker_<timestamp>;
  /// isi gallery/file manager pun tak bisa ditebak isinya apa.
  static String _randomName() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
  }
  // Key derivasi konsisten 32 byte (AES-256)
  static final Key _key = Key.fromUtf8('DyKalSecureStickerVault2026!Key'.padRight(32, '0'));

  static Future<Directory> dir() async {
    final path = await MediaSaver.getDirectory(category: 'stickers');
    return Directory(path);
  }

  static Future<List<File>> list() async {
    try {
      final d = await dir();
      return d.listSync().whereType<File>().where((f) {
        final p = f.path.toLowerCase();
        return p.endsWith('.webp.crypt15') ||
            p.endsWith('.png') ||
            p.endsWith('.jpg') ||
            p.endsWith('.jpeg') ||
            p.endsWith('.webp') ||
            p.endsWith('.gif');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> add(File src) async {
    try {
      final d = await dir();
      final tmp = await getTemporaryDirectory();
      final webpPath = '${tmp.path}/stk_${DateTime.now().millisecondsSinceEpoch}.webp';
      final res = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        webpPath,
        quality: 85,
        format: CompressFormat.webp,
        minWidth: 512,
        minHeight: 512,
      );
      final webpBytes = (res != null) ? await File(res.path).readAsBytes() : await src.readAsBytes();
      final encrypted = _encrypt(Uint8List.fromList(webpBytes));
      final name = '${_randomName()}.webp.crypt15';
      final dest = '${d.path}/$name';
      await File(dest).writeAsBytes(encrypted);
      return dest;
    } catch (_) {
      return null;
    }
  }

  static Uint8List _encrypt(Uint8List data) {
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final enc = encrypter.encryptBytes(data, iv: iv);
    return Uint8List.fromList(iv.bytes + enc.bytes);
  }

  static Future<Uint8List?> readDecrypted(File f) async {
    try {
      if (!f.path.toLowerCase().endsWith('.crypt15')) return await f.readAsBytes();
      final data = await f.readAsBytes();
      if (data.length < 13) return null;
      final iv = IV(Uint8List.fromList(data.sublist(0, 12)));
      final ct = Encrypted(Uint8List.fromList(data.sublist(12)));
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      return Uint8List.fromList(encrypter.decryptBytes(ct, iv: iv));
    } catch (_) {
      return null;
    }
  }

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
