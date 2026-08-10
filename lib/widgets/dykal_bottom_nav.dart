import 'package:flutter/material.dart';
import '../config/theme.dart';

class DyKalBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DyKalBottomNav({super.key, required this.currentIndex, required this.onTap});

  // Ikon custom dari aset (on/off) — Home, Album, Surat, Profil
  static const _icons = [
    ('assets/icons/home_on.webp', 'assets/icons/home_off.webp'),
    ('assets/icons/album_on.webp', 'assets/icons/album_off.webp'),
    ('assets/icons/surat_cinta_on.webp', 'assets/icons/surat_cinta_off.webp'),
    ('assets/icons/profile_on.webp', 'assets/icons/profile_off.webp'),
  ];

  static const _labels = ['Home', 'Album', 'Surat', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? DyKalTheme.surfaceDark.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? DyKalTheme.borderSoftDark : DyKalTheme.borderSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < 4; i++) _item(i, context),
          ],
        ),
      ),
    );
  }

  Widget _item(int idx, BuildContext context) {
    final isSelected = currentIndex == idx;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? DyKalTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon aset (on saat aktif, off saat tidak)
            Image.asset(
              isSelected ? _icons[idx].$1 : _icons[idx].$2,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.circle,
                size: 22,
                color: isSelected ? DyKalTheme.primary : DyKalTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _labels[idx],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? DyKalTheme.primary : DyKalTheme.textSecondaryOf(context),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
