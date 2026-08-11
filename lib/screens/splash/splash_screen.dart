import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Splash DyKal — versi STATIK (perintah owner 2026-08-12, pembatalan #10):
/// tanpa animasi sama sekali. Logo + nama app berdampingan, tulisan kecil
/// "Dyaa & Kall" di bawahnya. Auto-lanjut ~1.6 dtk, ketuk layar = skip.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _auto;
  Timer? _fallback;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _auto = Timer(const Duration(milliseconds: 1600), _finish);
    // Pengaman: apa pun yang terjadi, jangan biarkan app menggantung di splash.
    _fallback = Timer(const Duration(seconds: 5), _finish);
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish, // ketuk di mana pun = skip
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DyKalTheme.background, // warm white
                Color(0xFFFFE9EE),     // blush rose lembut
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo + nama app BERDAMPINGAN (statik)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo/dykal_logo_transparent.png',
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.favorite, size: 64, color: DyKalTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'DyKal',
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dyaa & Kall',
                    style: TextStyle(
                      fontSize: 13,
                      color: DyKalTheme.textGrey,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
