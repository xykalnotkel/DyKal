import 'package:flutter/material.dart';

/// Logger dev: rekam info/warning/error di memory, live update via ValueNotifier.
class DevLogger {
  static final DevLogger instance = DevLogger._();
  DevLogger._();

  final List<DevLogEntry> _logs = [];
  final ValueNotifier<int> update = ValueNotifier(0);
  static const _max = 1000;

  void info(String tag, String msg) => _add(LogLevel.info, tag, msg);
  void warning(String tag, String msg) => _add(LogLevel.warning, tag, msg);
  void error(String tag, String msg, [dynamic e]) =>
      _add(LogLevel.error, tag, e != null ? '$msg => $e' : msg);

  void _add(LogLevel level, String tag, String msg) {
    _logs.add(DevLogEntry(level, tag, msg, DateTime.now()));
    if (_logs.length > _max) _logs.removeAt(0);
    update.value++;
  }

  List<DevLogEntry> get logs => List.unmodifiable(_logs);

  String get copyText => _logs
      .map((e) =>
          '[${e.time.toIso8601String().substring(11, 19)}] ${e.level.name.toUpperCase().padRight(7)} [${e.tag.padRight(12)}] ${e.msg}')
      .join('\n');

  void clear() {
    _logs.clear();
    update.value++;
  }
}

enum LogLevel { info, warning, error }

class DevLogEntry {
  final LogLevel level;
  final String tag;
  final String msg;
  final DateTime time;
  DevLogEntry(this.level, this.tag, this.msg, this.time);
}
