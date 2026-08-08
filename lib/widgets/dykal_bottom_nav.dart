import 'package:flutter/material.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import '../config/theme.dart';

/// BottomNav DyKal - Mutlak tanpa emoji, icons Modern Rounded
/// Tidak diklik: Border style (Regular/Outline) • Diklik: Full/Fill style
class DyKalBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DyKalBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 72,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(0, Icons.home_outlined, Icons.home, "Home"),
            _item(1, Icons.collections_outlined, Icons.collections, "Album"),
            _item(2, Icons.mail_outline, Icons.mail, "Surat"),
            _item(3, Icons.person_outline, Icons.person, "Profil"),
          ],
        ),
      ),
    );
  }

  Widget _item(int idx, IconData iconBorder, IconData iconFill, String label) {
    final isSelected = currentIndex == idx;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? DyKalTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mutlak icons rounded: Border (regular outline) vs Fill (full)
            Icon(
              isSelected ? iconFill : iconBorder,
              color: isSelected ? DyKalTheme.primary : DyKalTheme.textGrey,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? DyKalTheme.primary : DyKalTheme.textGrey,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
