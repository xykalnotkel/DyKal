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
  int _style = 0;
  int get style => _style;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _style = p.getInt(key) ?? 0;
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
