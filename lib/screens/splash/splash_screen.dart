import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Splash DyKal — versi halus (anti "kaku"):
/// logo pop-in elastis -> dua "ular" menggambar outline love -> fade-out lembut.
/// Animasi ular-love dipertahankan sesuai permintaan owner (#10),
/// tapi sekarang ada transisi masuk & keluar yang mulus + latar gradient.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;    // logo pop-in
  late final AnimationController _main;     // ular-love + persen
  late final AnimationController _outro;    // fade-out keseluruhan
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
    _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _outro = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1.0);

    _intro.forward();
    _main.forward().whenComplete(() => _finish(animated: true));
    // Pengaman: apa pun yang terjadi, jangan biarkan app menggantung di splash.
    _fallback = Timer(const Duration(seconds: 5), _finish);
  }

  bool _finishing = false;

  /// Selesaikan splash sekali saja. [animated] = fade-out lembut dulu;
  /// false = langsung lanjut (fallback timer / hard-stop).
  Future<void> _finish({bool animated = false}) async {
    if (_finishing) return;
    _finishing = true;
    if (animated && mounted) await _outro.reverse();
    if (mounted) widget.onComplete();
  }

  /// TAP di mana pun = skip animasi, langsung masuk app.
  void _skip() {
    _intro.stop();
    _main.stop();
    _finish();
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _intro.dispose();
    _main.dispose();
    _outro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoScale = Tween(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
    final logoFade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final progress = CurvedAnimation(parent: _main, curve: Curves.easeInOut);

    return GestureDetector(
      onTap: _skip, // ketuk layar = skip splash
      child: FadeTransition(
        opacity: _outro,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DyKalTheme.background,   // warm white
                Color(0xFFFFE9EE),       // blush rose lembut
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo pop-in elastis + bayangan lembut
                ScaleTransition(
                  scale: logoScale,
                  child: FadeTransition(
                    opacity: logoFade,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: DyKalTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo/dykal_logo_transparent.png',
                        width: 104,
                        height: 104,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.favorite, size: 84, color: DyKalTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: logoFade,
                  child: Column(
                    children: [
                      const Text('DyKal',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      Text('Buat kamu & dia',
                          style: TextStyle(fontSize: 13, color: DyKalTheme.textGrey, letterSpacing: 0.3)),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Ular-love + persen (ikonik DyKal)
                AnimatedBuilder(
                  animation: progress,
                  builder: (_, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        painter: _SnakeHeartPainter(progress.value),
                        size: const Size(180, 150),
                      ),
                      const SizedBox(height: 10),
                      Text('${(progress.value * 100).toInt()}%',
                          style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Dua "ular" menelusuri outline love dari atas, masing-masing turun
/// ke sisi BERLAWANAN (kiri & kanan), berakhir ketemu di pucuk bawah love.
class _SnakeHeartPainter extends CustomPainter {
  final double progress; // 0..1
  _SnakeHeartPainter(this.progress);

  List<Offset> _heart(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 38.0;
    final pts = <Offset>[];
    const n = 160;
    for (int i = 0; i <= n; i++) {
      final t = (i / n) * 2 * math.pi;
      final x = (16 * math.pow(math.sin(t), 3)).toDouble();
      final y = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)).toDouble();
      pts.add(Offset(cx + x * scale, cy - y * scale));
    }
    return pts;
  }

  Path _pathOf(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _heart(size);
    final n = pts.length - 1; // 160
    final half = n ~/ 2;      // 80 (pucuk bawah love)
    final k = (progress * half).round().clamp(0, half);

    // 1) Track = outline love penuh (faint)
    final trackPaint = Paint()
      ..color = DyKalTheme.borderSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_pathOf(pts), trackPaint);

    // 2) Saat complete -> isi love tipis + glow
    if (progress >= 0.999) {
      canvas.drawPath(_pathOf(pts), Paint()..color = DyKalTheme.primary.withValues(alpha: 0.16));
    }

    final snakePaint = Paint()
      ..color = DyKalTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 3) Ular 1: dari atas (idx 0) turun sisi kanan ke idx k
    if (k > 0) {
      canvas.drawPath(_pathOf(pts.sublist(0, k + 1)), snakePaint);
    }
    // 4) Ular 2: dari atas (idx n) turun sisi KIRI (arah berlawanan) ke idx n-k
    if (k > 0) {
      canvas.drawPath(_pathOf(pts.sublist(n - k, n + 1)), snakePaint);
    }

    // 5) Kepala ular (titik berjalan + glow halus) di ujung masing-masing
    final headR = (progress < 0.999) ? 5.0 : 0.0;
    if (headR > 0) {
      final glow = Paint()
        ..color = DyKalTheme.primary.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pts[k], headR + 3, glow);
      canvas.drawCircle(pts[n - k], headR + 3, glow);
      final headPaint = Paint()..color = DyKalTheme.primary;
      canvas.drawCircle(pts[k], headR, headPaint);
      canvas.drawCircle(pts[n - k], headR, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeHeartPainter old) => old.progress != progress;
}
