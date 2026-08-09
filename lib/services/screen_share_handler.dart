import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// FIX screen share crash Android 14+:
/// Butuh foreground service type mediaProjection JALAN sebelum getDisplayMedia.
/// Handler ini cuma nyaga service hidup (gak ngapa-ngapain) selama screen share.
@pragma('vm:entry-point')
void startScreenShareCallback() {
  FlutterForegroundTask.setTaskHandler(_ScreenShareHandler());
}

class _ScreenShareHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}
