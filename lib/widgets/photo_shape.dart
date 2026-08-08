import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

enum PhotoShape { love, bulat, abstrak, bunga }

extension PhotoShapeX on PhotoShape {
  String get label => const {
        PhotoShape.love: 'Love',
        PhotoShape.bulat: 'Bulat',
        PhotoShape.abstrak: 'Abstrak',
        PhotoShape.bunga: 'Bunga',
      }[this]!;
  String get badgeAsset => 'assets/icons/badge_$name.png';
  IconData get icon => const {
        PhotoShape.love: Icons.favorite,
        PhotoShape.bulat: Icons.circle,
        PhotoShape.abstrak: Icons.bubble_chart,
        PhotoShape.bunga: Icons.local_florist,
      }[this]!;
}

PhotoShape shapeFromName(String? s) => PhotoShape.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PhotoShape.bulat,
    );

/// Foto dengan bingkai bentuk (Love/Bulat/Abstrak/Bunga) + badge AI di pojok.
class ShapedPhoto extends StatelessWidget {
  final String url;
  final PhotoShape shape;
  final double size;
  const ShapedPhoto({super.key, required this.url, required this.shape, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _clipperFor(shape),
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: DyKalTheme.borderSoft),
            ),
          ),
          Positioned(
            top: -10,
            right: -6,
            child: Image.asset(
              shape.badgeAsset,
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(shape.icon, color: DyKalTheme.primary, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  CustomClipper<Path> _clipperFor(PhotoShape s) {
    switch (s) {
      case PhotoShape.love:
        return const _HeartClipper();
      case PhotoShape.abstrak:
        return const _BlobClipper();
      case PhotoShape.bunga:
        return const _FlowerClipper();
      case PhotoShape.bulat:
        return const _CircleClipper();
    }
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();
  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2));
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeartClipper extends CustomClipper<Path> {
  const _HeartClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path();
    p.moveTo(0, h * 0.3);
    p.cubicTo(0, h * 0.08, w * 0.22, -h * 0.05, w * 0.5, h * 0.16);
    p.cubicTo(w * 0.78, -h * 0.05, w, h * 0.08, w, h * 0.3);
    p.cubicTo(w, h * 0.55, w * 0.7, h * 0.78, w * 0.5, h);
    p.cubicTo(w * 0.3, h * 0.78, 0, h * 0.55, 0, h * 0.3);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper();
  @override
  Path getClip(Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.shortestSide / 2;
    final p = Path();
    const n = 120;
    for (int i = 0; i <= n; i++) {
      final t = i / n * 2 * math.pi;
      final rr = r * (0.86 + 0.14 * math.cos(3 * t + 0.6));
      final x = cx + rr * math.cos(t);
      final y = cy + rr * math.sin(t);
      if (i == 0) p.moveTo(x, y);
      else p.lineTo(x, y);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FlowerClipper extends CustomClipper<Path> {
  const _FlowerClipper();
  @override
  Path getClip(Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.shortestSide / 2;
    final p = Path();
    const n = 160;
    const petals = 6;
    for (int i = 0; i <= n; i++) {
      final t = i / n * 2 * math.pi;
      final rr = r * (0.74 + 0.26 * math.cos(petals * t).abs());
      final x = cx + rr * math.cos(t);
      final y = cy + rr * math.sin(t);
      if (i == 0) p.moveTo(x, y);
      else p.lineTo(x, y);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
