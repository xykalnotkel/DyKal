import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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

      final ext = type == 'audio'
          ? 'm4a'
          : (type == 'video'
              ? 'mp4'
              : (type == 'stiker' || type == 'stickers' ? 'webp.crypt15' : 'jpg'));
      
      final fileName = 'DYKAL_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '$dirPath/$fileName';

      await Dio().download(url, filePath);
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
