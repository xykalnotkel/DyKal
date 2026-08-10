import 'package:flutter/material.dart';
import '../config/theme.dart';

class DyKalBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DyKalBottomNav({super.key, required this.currentIndex, required this.onTap});

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
            _item(0, Icons.home_outlined, Icons.home_rounded, 'Home', context),
            _item(1, Icons.collections_outlined, Icons.collections_rounded, 'Album', context),
            _item(2, Icons.mail_outline_rounded, Icons.mail_rounded, 'Surat', context),
            _item(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profil', context),
          ],
        ),
      ),
    );
  }

  Widget _item(int idx, IconData iconBorder, IconData iconFill, String label, BuildContext context) {
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
            Icon(
              isSelected ? iconFill : iconBorder,
              color: isSelected ? DyKalTheme.primary : DyKalTheme.textSecondaryOf(context),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
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
