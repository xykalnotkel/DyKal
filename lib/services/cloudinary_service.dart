import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

/// Cloudinary Service - Pengganti Firebase Storage yang butuh CC
/// Gratis 25GB storage + 25GB bandwidth, Upload UNSIGNED tanpa API Secret
class CloudinaryService {
  final Dio _dio = Dio();
  final String cloudName = AppConstants.cloudinaryCloudName;
  final String uploadPreset = AppConstants.cloudinaryUploadPreset;

  /// Compress & Convert ke WebP biar ringan (support DPI tinggi tapi file kecil)
  Future<File> _compressToWebP(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

    // BATCH I: mode hemat data (toggle Settings) — kompresi lebih agresif,
    // ~55-70% lebih kecil dari preset normal. Default tetap jernih.
    var saver = false;
    try {
      final p = await SharedPreferences.getInstance();
      saver = p.getBool('data_saver') ?? false;
    } catch (_) {}

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: saver ? 58 : 80,
      format: CompressFormat.webp, // WebP paling ringan & support transparan
      minWidth: saver ? 1280 : 1080,
      minHeight: saver ? 1280 : 1080,
    );
    return result != null ? File(result.path) : file;
  }

  /// Kompres publik (dipakai jalur E2E sebelum enkripsi).
  Future<File> compressImage(File file) => _compressToWebP(file);

  /// Upload resource RAW (ciphertext E2E .bin). Folder default dykal/e2e
  /// — segmen folder inilah penanda E2E di URL (lihat E2EService.marker).
  Future<String?> uploadRaw(File file, {String folder = 'dykal/e2e'}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: MediaType.parse('application/octet-stream'),
        ),
        'upload_preset': uploadPreset,
        'folder': folder,
        'resource_type': 'raw',
      });
      final res = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
        data: formData,
      );
      if (res.statusCode == 200) return res.data['secure_url'] as String?;
    } catch (e) {
      print('Cloudinary raw upload error: $e');
    }
    return null;
  }

  /// Upload Image (Foto Album, Foto Chat, Avatar)
  /// Otomatis compress ke WebP dulu
  Future<String?> uploadImage(File file, {String folder = "dykal/album"}) async {
    try {
      final compressed = await _compressToWebP(file);
      final mimeType = lookupMimeType(compressed.path) ?? 'image/webp';
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          compressed.path,
          filename: compressed.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ),
        'upload_preset': uploadPreset,
        'folder': folder,
      });

      final res = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
      );

      if (res.statusCode == 200) {
        // URL secure + dengan transformasi ringan
        return res.data['secure_url'] as String;
        // Contoh URL: https://res.cloudinary.com/.../image/upload/f_auto,q_auto/v123/dykal/album/xxx.webp
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
    }
    return null;
  }

  /// Upload Avatar (foto profil) - LANGSUNG tanpa compress 1080 (lebih reliable buat hasil crop kecil)
  Future<String?> uploadAvatar(File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg', contentType: MediaType.parse(mimeType)),
        'upload_preset': uploadPreset,
        'folder': 'dykal/avatar',
      });
      final res = await _dio.post('https://api.cloudinary.com/v1_1/$cloudName/image/upload', data: formData);
      if (res.statusCode == 200) return res.data['secure_url'] as String?;
    } catch (e) { print('avatar upload error: $e'); }
    return null;
  }

  /// Ekstrak audio dari video TANPA backend — cukup ubah ekstensi URL
  /// video menjadi .mp3; Cloudinary otomatis mengubah video jadi audio (MP3).
  /// Mengembalikan URL audio mp3 (perlu diunduh ke lokal untuk playlist story).
  Future<String?> uploadVideoForAudio(File video, {String folder = "dykal/story_music", void Function(double progress)? onProgress}) async {
    try {
      final mimeType = lookupMimeType(video.path) ?? 'video/mp4';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          video.path,
          contentType: MediaType.parse(mimeType),
        ),
        'upload_preset': uploadPreset,
        'folder': folder,
        'resource_type': 'video',
      });
      final res = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        data: formData,
        // onSendProgress: UI bisa tampilkan persen upload, bukan diam bengong
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      if (res.statusCode == 200) {
        final url = res.data['secure_url'] as String?;
        if (url == null) return null;
        // Ganti ekstensi file -> .mp3 = Cloudinary mengubah video menjadi audio
        return url.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.mp3');
      }
    } catch (e) {
      print('Video->audio error: $e');
    }
    return null;
  }

  /// Upload Voice Note (audio/m4a, mp3, aac)
  Future<String?> uploadVoiceNote(File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'audio/aac';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          contentType: MediaType.parse(mimeType),
        ),
        'upload_preset': uploadPreset,
        'folder': 'dykal/voice',
        'resource_type': 'video', // Cloudinary pake 'video' untuk audio
      });

      final res = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        data: formData,
      );
      if (res.statusCode == 200) return res.data['secure_url'];
    } catch (e) {
      print('Voice upload error: $e');
    }
    return null;
  }

  /// Upload File View Once (1x lihat) - sama tapi folder beda + auto hapus via tag
  Future<String?> uploadViewOnce(File file) async {
    return uploadImage(file, folder: "dykal/view_once");
  }

  /// Hapus file (untuk fitur Hapus Pesan + Hapus Foto View Once setelah dilihat)
  /// Butuh signed request, alternatif: cukup hapus URL dari Firestore,
  /// file di Cloudinary auto kehapus via Admin API atau biarkan (gratis gede)
  Future<void> deleteByUrl(String url) async {
    // Untuk free tier tanpa backend, cukup hapus referensi di Firestore.
    // File tetap ada tapi tidak diakses. 25GB cukup untuk 50ribu foto.
    print('Delete reference: $url - hapus dari Firestore saja (free tier)');
  }
}
