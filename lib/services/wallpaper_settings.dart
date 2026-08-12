import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan wallpaper kustom (permintaan owner Batch C):
/// - WALLPAPER CHAT: default (aset bawaan) / warna solid / foto dari galeri.
/// - LATAR BERANDA: foto dari galeri di belakang konten Home.
///
/// Foto yang dipilih DISALIN ke direktori privat aplikasi (bukan nyangkut
/// path galeri), jadi tetap ada walau file aslinya dipindah/dihapus user.
/// Singleton + ChangeNotifier: layar chat & home rebuild otomatis saat ganti.
class WallpaperSettings extends ChangeNotifier {
  WallpaperSettings._();
  static final WallpaperSettings instance = WallpaperSettings._();

  static const _kChatType = 'chat_bg_type'; // 0 default, 1 warna, 2 foto
  static const _kChatColor = 'chat_bg_color';
  static const _kChatPath = 'chat_bg_path';
  static const _kHomePath = 'home_bg_path';

  int _chatType = 0;
  int _chatColor = 0xFFFFF0F3; // pink muda DyKal
  String? _chatPath;
  String? _homePath;

  int get chatType => _chatType;
  Color get chatColor => Color(_chatColor);
  String? get chatPath => _chatPath;
  String? get homePath => _homePath;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _chatType = p.getInt(_kChatType) ?? 0;
      _chatColor = p.getInt(_kChatColor) ?? _chatColor;
      _chatPath = _valid(p.getString(_kChatPath));
      _homePath = _valid(p.getString(_kHomePath));
      notifyListeners();
    } catch (_) {}
  }

  /// Path valid = file-nya masih ada. Kalau sudah hilang, anggap null.
  static String? _valid(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      if (File(path).existsSync()) return path;
    } catch (_) {}
    return null;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kChatType, _chatType);
    await p.setInt(_kChatColor, _chatColor);
    if (_chatPath != null) {
      await p.setString(_kChatPath, _chatPath!);
    } else {
      await p.remove(_kChatPath);
    }
    if (_homePath != null) {
      await p.setString(_kHomePath, _homePath!);
    } else {
      await p.remove(_kHomePath);
    }
  }

  /// Salin foto pilihan user ke direktori privat aplikasi.
  Future<String> _importImage(File src, String prefix) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/wallpapers');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = src.path.contains('.') ? src.path.split('.').last : 'jpg';
    final dest = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> setChatDefault() async {
    _chatType = 0;
    _chatPath = null;
    notifyListeners();
    await _persist();
  }

  Future<void> setChatColor(Color c) async {
    _chatType = 1;
    _chatColor = c.toARGB32();
    _chatPath = null;
    notifyListeners();
    await _persist();
  }

  Future<void> setChatImage(File src) async {
    try {
      _chatPath = await _importImage(src, 'chat');
      _chatType = 2;
      notifyListeners();
      await _persist();
    } catch (_) {}
  }

  Future<void> setHomeImage(File src) async {
    try {
      _homePath = await _importImage(src, 'home');
      notifyListeners();
      await _persist();
    } catch (_) {}
  }

  Future<void> clearHome() async {
    _homePath = null;
    notifyListeners();
    await _persist();
  }

  /// Dekorasi background layar chat. Mengembalikan null saat type=0
  /// (layar chat pakai aset bawaan light/dark seperti biasa).
  BoxDecoration? chatDecoration({required bool dark}) {
    switch (_chatType) {
      case 1:
        return BoxDecoration(color: chatColor);
      case 2:
        final path = _chatPath;
        if (path != null && File(path).existsSync()) {
          return BoxDecoration(
            image: DecorationImage(
              image: FileImage(File(path)),
              fit: BoxFit.cover,
              // Sedikit digelapkan di mode gelap biar gelembung tetap kebaca.
              colorFilter: dark
                  ? ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken)
                  : null,
            ),
          );
        }
        return null;
      default:
        return null;
    }
  }
}
