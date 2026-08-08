import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Scaffold Seamless DyKal - Tanpa garis pemisah
/// TopBar & BottomNav nyatu dengan background utama (tema-aware + bottom nav tanpa background).
class SeamlessScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;

  const SeamlessScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: extendBody, // Biar konten menggulung di belakang nav transparan
      extendBodyBehindAppBar: true,
      backgroundColor: dark ? DyKalTheme.backgroundDark : DyKalTheme.background,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(
          // Background gradient halus biar ga flat (light & dark)
          gradient: LinearGradient(
            colors: dark
                ? const [DyKalTheme.backgroundDark, Color(0xFF0E1014)]
                : const [DyKalTheme.background, Color(0xFFFFF0F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: body,
      ),
      // Bottom nav TANPA background solid (transparan, nyatu)
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
