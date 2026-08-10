import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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

class UpdateService extends ChangeNotifier {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const _installerChannel = MethodChannel('dykal/installer');

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
      final doc = await FirebaseFirestore.instance.doc('app_config/update').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final remoteVersionCode = (data['versionCode'] as num?)?.toInt() ?? 0;
        final remoteVersionName = (data['versionName'] as String?) ?? '1.0.0';
        final apkUrl = (data['apkUrl'] as String?) ?? '';
        final notes = (data['releaseNotes'] as String?) ?? 'Pembaruan stabilitas dan fitur baru';
        final force = (data['isForce'] as bool?) ?? false;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

        if (remoteVersionCode > currentBuildNumber && apkUrl.isNotEmpty) {
          availableUpdate = UpdateInfo(
            versionName: remoteVersionName,
            versionCode: remoteVersionCode,
            apkUrl: apkUrl,
            releaseNotes: notes,
            isForce: force,
          );
        } else {
          availableUpdate = null;
        }
      }
    } catch (_) {
      availableUpdate = null;
    } finally {
      isChecking = false;
      notifyListeners();
    }
  }

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

      // Trigger native installer
      await _installerChannel.invokeMethod('installApk', {'filePath': savePath});
    } catch (e) {
      isDownloading = false;
      notifyListeners();
    }
  }
}
