import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skala font global (Batch I — aksesibilitas): 0.90 kecil / 1.00 normal /
/// 1.12 besar. Reaktif tanpa restart via ValueListenableBuilder di main.
class FontScale {
  static const _key = 'font_scale';
  static final ValueNotifier<double> value = ValueNotifier(1.0);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      value.value = p.getDouble(_key) ?? 1.0;
    } catch (_) {}
  }

  static Future<void> set(double v) async {
    value.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_key, v);
    } catch (_) {}
  }
}
