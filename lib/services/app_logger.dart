import 'dart:io';

/// Logger aplikasi: tulis error/info ke Android/media/com.dykal.app/logs/app.log
class AppLogger {
  static const _pkg = 'com.dykal.app';

  static Future<File> _file() async {
    final d = Directory('/storage/emulated/0/Android/media/$_pkg/logs');
    try {
      if (!await d.exists()) await d.create(recursive: true);
    } catch (_) {
      // fallback ke app data
      final fb = Directory('/storage/emulated/0/Android/data/$_pkg/files/logs');
      if (!await fb.exists()) await fb.create(recursive: true);
      return File('${fb.path}/app.log');
    }
    return File('${d.path}/app.log');
  }

  static Future<void> log(String msg) async {
    try {
      final f = await _file();
      final ts = DateTime.now().toIso8601String();
      await f.writeAsString('[$ts] $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  static Future<void> error(String tag, dynamic e, [StackTrace? s]) async {
    await log('ERROR [$tag]: $e');
    if (s != null) await log('STACK: $s');
  }
}
