import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Scaffold Seamless DyKal - Tanpa garis pemisah
/// TopBar & BottomNav nyatu dengan background utama
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
    return Scaffold(
      extendBody: extendBody, // Biar BottomNav transparan nyatu
      extendBodyBehindAppBar: true,
      backgroundColor: DyKalTheme.background,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(
          color: DyKalTheme.background,
          // Background gradient halus biar ga flat
          gradient: LinearGradient(
            colors: [DyKalTheme.background, Color(0xFFFFF0F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar != null
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                // Efek blur + tanpa border tegas
                border: Border(top: BorderSide(color: Colors.transparent)), // HAPUS GARIS
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                child: bottomNavigationBar,
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
