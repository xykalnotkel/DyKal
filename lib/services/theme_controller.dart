import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppUiStyle {
  rounded,   // Modern Material 3 (Radius 20-24px, pill shapes)
  ios,       // Cupertino iOS Style (Radius 12-14px, flat frosted design)
  sharp,     // Minimalist Sharp (Radius 6-8px, clean brutalist)
}

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  AppUiStyle _style = AppUiStyle.rounded;
  AppUiStyle get style => _style;

  static const _keyMode = 'dykal_theme_mode';
  static const _keyStyle = 'dykal_ui_style';

  // BATCH H (aturan owner): SEMUA komponen minimal rounded — tidak ada radius
  // tajam di bawah 12 di mana pun lewat jalan tema. Perbedaan gaya kini hanya
  // nuansa (seberapa tumpul), bukan tajam vs bulat.
  double get cardRadius {
    switch (_style) {
      case AppUiStyle.rounded:
        return 24.0;
      case AppUiStyle.ios:
        return 16.0;
      case AppUiStyle.sharp:
        return 10.0;
    }
  }

  double get buttonRadius {
    switch (_style) {
      case AppUiStyle.rounded:
        return 20.0;
      case AppUiStyle.ios:
        return 14.0;
      case AppUiStyle.sharp:
        return 10.0;
    }
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_keyMode);
      _mode = v == 'light'
          ? ThemeMode.light
          : v == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system;

      final s = p.getString(_keyStyle);
      _style = s == 'ios'
          ? AppUiStyle.ios
          : s == 'sharp'
              ? AppUiStyle.sharp
              : AppUiStyle.rounded;

      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyMode, m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system');
    } catch (_) {}
  }

  Future<void> setStyle(AppUiStyle s) async {
    _style = s;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyStyle, s == AppUiStyle.ios ? 'ios' : s == AppUiStyle.sharp ? 'sharp' : 'rounded');
    } catch (_) {}
  }
}
