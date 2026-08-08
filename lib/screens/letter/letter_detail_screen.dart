import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Layar surat dengan animasi: amplop tertutup + segel love -> ketuk -> segel pecah,
/// flap terbuka, kertas surat keluar & membesar. Ketuk lagi untuk menutup (reverse).
class LetterDetailScreen extends StatefulWidget {
  final String text;
  final String fromName;
  final DateTime? createdAt;
  const LetterDetailScreen({super.key, required this.text, required this.fromName, this.createdAt});

  @override
  State<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _c.reverse();
    } else {
      _c.forward();
    }
    setState(() => _open = !_open);
  }

  double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final sealP = _seg(t, 0.0, 0.2);
                final flapP = _seg(t, 0.1, 0.5);
                final cardP = _seg(t, 0.35, 1.0);
                return SizedBox(
                  width: 340,
                  height: 460,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Amplop + segel (membesar/meredup sedikit saat terbuka)
                      Transform.scale(
                        scale: 1 - cardP * 0.12,
                        child: Opacity(
                          opacity: 1 - cardP * 0.4,
                          child: _envelope(flapP, sealP),
                        ),
                      ),
                      // Kertas surat yang keluar & membesar
                      Opacity(
                        opacity: cardP,
                        child: Transform.scale(
                          scale: 0.2 + cardP * 0.85,
                          child: _letterCard(),
                        ),
                      ),
                      // Tombol tutup (muncul saat terbuka)
                      if (cardP > 0.9)
                        Positioned(
                          top: 4,
                          right: 0,
                          child: IconButton(
                            onPressed: _toggle,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _envelope(double flapP, double sealP) {
    return SizedBox(
      width: 300,
      height: 230,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Badan amplop (belakang)
          Positioned(
            bottom: 0,
            child: Container(
              width: 300,
              height: 190,
              decoration: BoxDecoration(gradient: DyKalTheme.loveGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
            ),
          ),
          // Saku depan (bagian bawah)
          Positioned(
            bottom: 0,
            child: Container(
              width: 300,
              height: 105,
              decoration: BoxDecoration(
                color: const Color(0xFFE85A7A),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
            ),
          ),
          // Flap (segitiga) yang terbuka
          Positioned(
            top: 0,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(math.pi * flapP),
              child: CustomPaint(
                size: const Size(300, 95),
                painter: _FlapPainter(),
              ),
            ),
          ),
          // Segel love di tengah flap
          Positioned(
            top: 60,
            child: Opacity(
              opacity: 1 - sealP,
              child: Transform.scale(
                scale: 1 - sealP,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: DyKalTheme.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: DyKalTheme.accent.withOpacity(0.5), blurRadius: 12)]),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _letterCard() {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.favorite, color: DyKalTheme.primary, size: 18), const SizedBox(width: 6), Text("Dari ${widget.fromName}", style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFF6B8A)))]),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Text(widget.text, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF1A1C1E))),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.createdAt != null)
            Align(alignment: Alignment.centerRight, child: Text(_fmt(widget.createdAt!), style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11, fontStyle: FontStyle.italic))),
          const SizedBox(height: 8),
          Align(alignment: Alignment.center, child: Icon(Icons.favorite, color: DyKalTheme.primary.withOpacity(0.4), size: 16)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => "${d.day}/${d.month}/${d.year}";
}

class _FlapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF8E9E);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
