import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'e2e_service.dart';

/// WhatsApp-style Scoped Media Storage Engine for Android 10+ (API 29+)
/// Base Directory: Android/media/com.dykal.app/Dykal/Media/
class MediaSaver {
  static const String pkgName = 'com.dykal.app';

  /// Inisialisasi dan kembalikan direktori spesifik media dengan .nomedia otomatis
  static Future<String> getDirectory({
    required String category, // 'images' | 'video' | 'audio' | 'voice' | 'documents' | 'stickers'
    bool isSent = false,
    bool isPrivate = false,
  }) async {
    String baseRoot = '/storage/emulated/0/Android/media/$pkgName/Dykal/Media';
    
    // Fallback jika emulated path tidak dapat diakses
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null && !await Directory(baseRoot).exists()) {
        baseRoot = '${ext.path}/Media';
      }
    } catch (_) {}

    String subFolder;
    bool needsNoMedia = false;

    switch (category.toLowerCase()) {
      case 'images':
      case 'foto':
        if (isPrivate) {
          subFolder = 'Dykal Images/Private';
          needsNoMedia = true;
        } else if (isSent) {
          subFolder = 'Dykal Images/Sent';
          needsNoMedia = true;
        } else {
          subFolder = 'Dykal Images';
        }
        break;

      case 'video':
        if (isSent) {
          subFolder = 'Dykal Video/Sent';
          needsNoMedia = true;
        } else {
          subFolder = 'Dykal Video';
        }
        break;

      case 'voice':
      case 'voicenote':
        subFolder = 'Dykal Audio/Dykal Voice Notes';
        needsNoMedia = true;
        break;

      case 'audio':
        subFolder = 'Dykal Audio';
        break;

      case 'stickers':
      case 'stiker':
        subFolder = 'Dykal Stickers';
        needsNoMedia = true;
        break;

      case 'documents':
      default:
        subFolder = 'Dykal Documents';
        break;
    }

    final targetDir = Directory('$baseRoot/$subFolder');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    if (needsNoMedia) {
      final noMediaFile = File('${targetDir.path}/.nomedia');
      if (!await noMediaFile.exists()) {
        await noMediaFile.create();
      }
    }

    return targetDir.path;
  }

  /// Download media dari URL dan simpan ke struktur folder terorganisir
  static Future<String?> save(
    String url, {
    String type = 'foto',
    bool isSent = false,
    bool isPrivate = false,
  }) async {
    try {
      final dirPath = await getDirectory(
        category: type,
        isSent: isSent,
        isPrivate: isPrivate,
      );

      final e2e = E2EService.isEncryptedUrl(url);
      var ext = type == 'audio'
          ? 'm4a'
          : (type == 'video'
              ? 'mp4'
              : (type == 'stiker' || type == 'stickers' ? 'webp.crypt15' : 'jpg'));
      // Foto E2E aslinya WebP terenkripsi — simpan dengan ekstensi yang benar
      // (menamai ciphertext/plaintext webp sebagai .jpg bikin galeri bingung).
      if (e2e && (type == 'foto' || type == 'images')) ext = 'webp';

      final fileName = 'DYKAL_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '$dirPath/$fileName';

      // BATCH L: sadar E2E — unduh dulu sebagai byte; kalau URL terenkripsi,
      // dekripsi baru ditulis (menyimpan ciphertext = file sampah .jpg).
      final res = await Dio()
          .get<List<int>>(url, options: Options(responseType: ResponseType.bytes))
          .timeout(const Duration(seconds: 90));
      var data = res.data;
      if (data == null || data.isEmpty) return null;
      Uint8List bytes = Uint8List.fromList(data);
      if (e2e) {
        final plain = await E2EService.decryptBlob(bytes);
        if (plain == null) return null; // kunci belum siap / blob korup
        bytes = plain;
      }
      await File(filePath).writeAsBytes(bytes, flush: true);
      return filePath;
    } catch (_) {
      return null;
    }
  }

  /// Simpan copy file lokal yang baru saja dikirim ke folder Sent
  static Future<String?> saveSentCopy(File sourceFile, {String type = 'foto'}) async {
    try {
      final dirPath = await getDirectory(category: type, isSent: true);
      final ext = sourceFile.path.split('.').last;
      final fileName = 'DYKAL_SENT_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destFile = File('$dirPath/$fileName');
      await sourceFile.copy(destFile.path);
      return destFile.path;
    } catch (_) {
      return null;
    }
  }
}
