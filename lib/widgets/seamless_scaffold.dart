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
        // FIX ATURAN: user larang gradient -> background solid (tema-aware)
        color: dark ? DyKalTheme.backgroundDark : DyKalTheme.background,
        child: body,
      ),
      // Bottom nav TANPA background solid (transparan, nyatu)
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
