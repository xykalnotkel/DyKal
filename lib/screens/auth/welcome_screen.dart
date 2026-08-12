import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _lang = 'Indonesia';

  void _showLangPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Bahasa Aplikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.language, color: DyKalTheme.primary),
                title: const Text('Bahasa Indonesia', style: TextStyle(color: Colors.white)),
                trailing: _lang == 'Indonesia' ? const Icon(Icons.check_circle, color: DyKalTheme.primary) : null,
                onTap: () {
                  setState(() => _lang = 'Indonesia');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.white70),
                title: const Text('English (US)', style: TextStyle(color: Colors.white)),
                trailing: _lang == 'English (US)' ? const Icon(Icons.check_circle, color: DyKalTheme.primary) : null,
                onTap: () {
                  setState(() => _lang = 'English (US)');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    AuthService().seenWelcome = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('seen_welcome', true);
      await p.setString('app_language', _lang);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: InkWell(
                  onTap: _showLangPicker,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: DyKalTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language, size: 18, color: DyKalTheme.primary),
                        const SizedBox(width: 8),
                        Text(_lang, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: DyKalTheme.primary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18, color: DyKalTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/illustrations/auth_login.webp',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/logo/dykal_logo_transparent.png',
                    width: 140,
                    height: 140,
                    errorBuilder: (_, ___, ____) => Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(30)),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Selamat Datang di DyKal',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: DyKalTheme.textPrimaryOf(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Ruang digital privat untuk kamu & dia. Satu aplikasi, dua orang, nol distraksi.',
                style: TextStyle(fontSize: 14, color: DyKalTheme.textSecondaryOf(context), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                'Baca Kebijakan Privasi dan Aturan Keamanan End-to-End kami.',
                style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _continue,
                  child: const Text('Setuju & Lanjutkan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
