import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Splash screen dengan animasi progress love
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
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
        // Logo
        Image.asset('assets/logo/dykal_logo_hd.png', width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.favorite, size: 80, color: DyKalTheme.primary)),
        const SizedBox(height: 24),
        const Text('DyKal', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 32),
        // Progress bar berbentuk love
        SizedBox(width: 200, child: AnimatedBuilder(
          animation: _progress,
          builder: (_, child) => CustomPaint(painter: _HeartProgressPainter(_progress.value), size: const Size(200, 60)),
        )),
        const SizedBox(height: 16),
        Text('${(_progress.value * 100).toInt()}%', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
      ])),
    );
  }
}

class _HeartProgressPainter extends CustomPainter {
  final double progress;
  _HeartProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Background track
    final bgPaint = Paint()..color = DyKalTheme.borderSoft;
    final trackRect = RRect.fromRectXY(Rect.fromLTWH(0, size.height/2 - 3, size.width, 6), 3, 3);
    canvas.drawRRect(trackRect, bgPaint);

    // Progress fill (kiri ke kanan, lalu kanan ke kiri = ular)
    final fillPaint = Paint()..color = DyKalTheme.primary;
    double w;
    if (progress < 0.5) {
      w = size.width * (progress * 2);
      canvas.drawRRect(RRect.fromRectXY(Rect.fromLTWH(0, size.height/2 - 3, w, 6), 3, 3), fillPaint);
    } else {
      // Kiri penuh + kanan mulai dari kanan ke kiri
      canvas.drawRRect(RRect.fromRectXY(Rect.fromLTWH(0, size.height/2 - 3, size.width, 6), 3, 3), fillPaint);
      // Heart icon di tengah saat complete
      if (progress > 0.8) {
        final heartPaint = Paint()..color = DyKalTheme.primary.withOpacity((progress - 0.8) * 5);
        final cx = size.width / 2, cy = size.height / 2;
        final path = Path();
        path.moveTo(cx, cy + 8);
        path.cubicTo(cx - 12, cy - 2, cx - 12, cy - 10, cx, cy - 4);
        path.cubicTo(cx + 12, cy - 10, cx + 12, cy - 2, cx, cy + 8);
        canvas.drawPath(path, heartPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartProgressPainter old) => old.progress != progress;
}
