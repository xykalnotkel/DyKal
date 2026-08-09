import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Splash screen dengan animasi "ular" mendaki dari kiri & kanan
/// ke arah berlawanan menyusun outline love (perintah owner #10).
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _progress = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward().whenComplete(() => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/logo/dykal_logo_hd.png', width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.favorite, size: 80, color: DyKalTheme.primary)),
        const SizedBox(height: 24),
        const Text('DyKal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 32),
        // Animasi ular-love
        AnimatedBuilder(
          animation: _progress,
          builder: (_, child) => CustomPaint(painter: _SnakeHeartPainter(_progress.value), size: const Size(200, 180)),
        ),
        const SizedBox(height: 16),
        Text('${(_progress.value * 100).toInt()}%', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
      ])),
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

    // 2) Saat complete -> isi love tipis
    if (progress >= 0.999) {
      final fill = Paint()..color = DyKalTheme.primary.withOpacity(0.16);
      canvas.drawPath(_pathOf(pts), fill);
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

    // 5) Kepala ular (titik berjalan) di ujung masing-masing
    final headPaint = Paint()..color = DyKalTheme.primary;
    final headR = (progress < 0.999) ? 5.0 : 0.0;
    if (headR > 0) {
      canvas.drawCircle(pts[k], headR, headPaint);
      canvas.drawCircle(pts[n - k], headR, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeHeartPainter old) => old.progress != progress;
}
