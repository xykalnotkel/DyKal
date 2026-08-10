import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool isForce;

  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    this.isForce = false,
  });
}

/// Service update in-app.
/// Sumber utama: GitHub Release terbaru (changelog + APK asset) dari repo publik.
/// Fallback: dokumen Firestore `app_config/update`.
/// Download berjalan asinkron (tetap jalan walau banner ditutup) dan otomatis
/// membuka installer Android saat selesai.
class UpdateService extends ChangeNotifier {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const _installerChannel = MethodChannel('dykal/installer');
  static const _repoOwner = 'xykalnotkel';
  static const _repoName = 'DyKal';
  static const _githubReleaseApi =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  UpdateInfo? availableUpdate;
  bool isChecking = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String? localApkPath;

  Future<void> checkForUpdate() async {
    if (isChecking || isDownloading) return;
    isChecking = true;
    notifyListeners();
    try {
      availableUpdate = await _checkGithubRelease() ?? await _checkFirestoreConfig();
    } catch (_) {
      availableUpdate = null;
    } finally {
      isChecking = false;
      notifyListeners();
    }
  }

  /// Ambil rilis terbaru dari GitHub (changelog di `body`, APK di `assets`).
  Future<UpdateInfo?> _checkGithubRelease() async {
    try {
      final resp = await http
          .get(Uri.parse(_githubReleaseApi))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final versionName = tag.startsWith('v') ? tag.substring(1) : tag;
      final notes = (data['body'] as String?) ?? '';
      final assets = (data['assets'] as List?) ?? [];

      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] as String?) ?? '';
        if (!name.endsWith('.apk')) continue;
        if (apkUrl == null) apkUrl = a['browser_download_url'] as String?;
        if (name.contains('arm64')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (versionName.isEmpty || apkUrl == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (_compareVersion(versionName, packageInfo.version) > 0) {
        return UpdateInfo(
          versionName: versionName,
          versionCode: int.tryParse(versionName.replaceAll('.', '')) ?? 0,
          apkUrl: apkUrl,
          releaseNotes: notes,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fallback: konfigurasi update dari Firestore.
  Future<UpdateInfo?> _checkFirestoreConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('app_config/update').get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      final remoteVersionCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final remoteVersionName = (data['versionName'] as String?) ?? '1.0.0';
      final apkUrl = (data['apkUrl'] as String?) ?? '';
      final notes = (data['releaseNotes'] as String?) ?? 'Pembaruan stabilitas dan fitur baru';
      final force = (data['isForce'] as bool?) ?? false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      if (remoteVersionCode > currentBuildNumber && apkUrl.isNotEmpty) {
        return UpdateInfo(
          versionName: remoteVersionName,
          versionCode: remoteVersionCode,
          apkUrl: apkUrl,
          releaseNotes: notes,
          isForce: force,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Bandingkan semver "a.b.c" vs "x.y.z". Return >0 bila a lebih baru.
  static int _compareVersion(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  /// Download APK dengan progres, lalu jalankan installer Android.
  /// Berjalan asinkron; banner boleh ditutup, download tetap lanjut.
  Future<void> downloadAndInstall() async {
    if (availableUpdate == null || isDownloading) return;

    isDownloading = true;
    downloadProgress = 0.0;
    notifyListeners();

    try {
      final tempDir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final savePath = '${tempDir.path}/dykal_update_${availableUpdate!.versionCode}.apk';
      localApkPath = savePath;

      final dio = Dio();
      await dio.download(
        availableUpdate!.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress = (received / total).clamp(0.0, 1.0);
            notifyListeners();
          }
        },
      );

      isDownloading = false;
      notifyListeners();

      // Trigger native installer (FileProvider sudah dikonfigurasi di MainActivity)
      await _installerChannel.invokeMethod('installApk', {'filePath': savePath});
    } catch (e) {
      isDownloading = false;
      notifyListeners();
    }
  }
}
