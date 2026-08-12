import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'fcm_service.dart';

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool isForce;
  // Nama aset APK yang dipilih sesuai ABI device (info/debug UI)
  final String? apkAssetName;

  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    this.isForce = false,
    this.apkAssetName,
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

  // Cache ABI device (tidak berubah selama proses hidup)
  List<String>? _abisCache;

  /// ABI yang didukung HP ini, urutan = preferensi sistem ([0] = ABI utama).
  /// Contoh HP 64-bit: [arm64-v8a, armeabi-v7a, armeabi]. Fallback aman arm64.
  Future<List<String>> _supportedAbis() async {
    final cached = _abisCache;
    if (cached != null) return cached;
    try {
      final res = await _installerChannel.invokeMethod<List<dynamic>>('getSupportedAbis');
      if (res != null && res.isNotEmpty) {
        _abisCache = res.whereType<String>().toList();
        if (_abisCache!.isNotEmpty) return _abisCache!;
      }
    } catch (_) {}
    _abisCache = const ['arm64-v8a'];
    return _abisCache!;
  }

  /// Pilih aset APK release yang cocok dengan ABI device.
  /// Kenapa wajib: salah ABI -> install ditolak Android (NO_MATCHING_ABI).
  /// Rantai fallback: ABI cocok -> universal -> arm64 -> APK pertama.
  static ({String url, String name})? _pickApkAsset(List<dynamic> assets, List<String> abis) {
    final apks = <Map<String, dynamic>>[];
    for (final a in assets) {
      if (a is Map &&
          ((a['name'] as String?) ?? '').endsWith('.apk') &&
          a['browser_download_url'] is String) {
        apks.add(a.cast<String, dynamic>());
      }
    }
    if (apks.isEmpty) return null;

    ({String url, String name})? findBy(String key) {
      for (final a in apks) {
        final name = a['name'] as String;
        if (name.contains(key)) {
          final url = a['browser_download_url'] as String?;
          if (url != null) return (url: url, name: name);
        }
      }
      return null;
    }

    for (final abi in abis) {
      final key = switch (abi) {
        'arm64-v8a' => 'arm64',
        'armeabi-v7a' || 'armeabi' => 'armeabi-v7a',
        'x86_64' || 'x86' => 'x86_64',
        _ => abi,
      };
      final hit = findBy(key);
      if (hit != null) return hit;
    }
    return findBy('universal') ?? findBy('arm64') ??
        (url: apks.first['browser_download_url'] as String, name: apks.first['name'] as String);
  }

  Future<void> checkForUpdate() async {
    if (isChecking || isDownloading) return;
    isChecking = true;
    notifyListeners();
    try {
      availableUpdate = await _checkGithubRelease() ?? await _checkFirestoreConfig();
      // Batch D: update realtime — bukan cuma banner di home, muncul juga
      // sebagai NOTIFIKASI SISTEM dengan aksi "Unduh Sekarang".
      if (availableUpdate != null) {
        try { await FCMService().showUpdateNotif(availableUpdate!.versionName); } catch (_) {}
      }
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

      // Deteksi ABI HP lalu pilih APK yang cocok (32-bit jangan ditawari arm64!)
      final abis = await _supportedAbis();
      final pick = _pickApkAsset(assets, abis);
      if (pick == null) return null;
      if (versionName.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (_compareVersion(versionName, packageInfo.version) > 0) {
        return UpdateInfo(
          versionName: versionName,
          versionCode: int.tryParse(versionName.replaceAll('.', '')) ?? 0,
          apkUrl: pick.url,
          apkAssetName: pick.name,
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
