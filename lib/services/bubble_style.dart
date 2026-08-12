import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kontrol gaya gelembung chat (0 Bulat / 1 Kotak / 2 Ekor / 3 Pil / 4 Abstrak).
/// FIX (laporan owner): dulu preferensi 'bubble_style' disimpan dari Settings
/// DAN dialog di chat, tapi MessageBubble tidak pernah membacanya — radius
/// hardcoded, jadi pilihan pengguna pajangan belaka. Sekarang satu sumber
/// kebenaran singleton; MessageBubble membaca dari sini setiap build.
class BubbleStyle extends ChangeNotifier {
  BubbleStyle._();
  static final BubbleStyle instance = BubbleStyle._();

  static const key = 'bubble_style';
  static const metaKey = 'bubble_meta_inside';
  int _style = 0;
  int get style => _style;

  /// Posisi status terkirim & waktu (permintaan owner):
  /// true = di DALAM bubble (ala WA), false = di LUAR bawah bubble (ala iOS).
  bool _metaInside = true;
  bool get metaInside => _metaInside;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _style = p.getInt(key) ?? 0;
      _metaInside = p.getBool(metaKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(int s) async {
    _style = s;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(key, s);
    } catch (_) {}
  }

  Future<void> setMetaInside(bool inside) async {
    _metaInside = inside;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(metaKey, inside);
    } catch (_) {}
  }

  /// Radius gelembung sesuai gaya aktif. [isMe] = gelembung milikku (kanan).
  BorderRadius radius(bool isMe) {
    switch (_style) {
      case 1: // Kotak — tegas semua sudut
        return BorderRadius.circular(8);
      case 2: // Ekor ala WA — sudut bawah-dekat tajam satu sisi
        return BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        );
      case 3: // Pil — kapsul penuh, radius maksimal
        return BorderRadius.circular(28);
      case 4: // Abstrak — campuran radius besar-kecil yang cair
        return BorderRadius.only(
          topLeft: Radius.circular(isMe ? 26 : 4),
          topRight: Radius.circular(isMe ? 4 : 26),
          bottomLeft: Radius.circular(isMe ? 14 : 26),
          bottomRight: Radius.circular(isMe ? 26 : 14),
        );
      case 0:
      default: // Bulat — lembut semua sudut
        return BorderRadius.circular(16);
    }
  }
}
