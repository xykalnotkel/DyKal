import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

enum PhotoShape { love, bulat, abstrak, bunga, hexagon, diamond, star, heart2 }

extension PhotoShapeX on PhotoShape {
  String get label => const {
        PhotoShape.love: 'Love',
        PhotoShape.bulat: 'Bulat',
        PhotoShape.abstrak: 'Abstrak',
        PhotoShape.bunga: 'Bunga',
        PhotoShape.hexagon: 'Hexagon',
        PhotoShape.diamond: 'Diamond',
        PhotoShape.star: 'Bintang',
        PhotoShape.heart2: 'Hati',
      }[this]!;
  String get badgeAsset => 'assets/icons/badge_$name.png';
  IconData get icon => const {
        PhotoShape.love: Icons.favorite,
        PhotoShape.bulat: Icons.circle,
        PhotoShape.abstrak: Icons.bubble_chart,
        PhotoShape.bunga: Icons.local_florist,
        PhotoShape.hexagon: Icons.extension,
        PhotoShape.diamond: Icons.change_history,
        PhotoShape.star: Icons.star,
        PhotoShape.heart2: Icons.favorite_border,
      }[this]!;
}

PhotoShape shapeFromName(String? s) => PhotoShape.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PhotoShape.bulat,
    );

/// Clipper publik per bentuk (dipakai album cover placeholder dsb.)
CustomClipper<Path> photoShapeClipper(PhotoShape s) {
  switch (s) {
    case PhotoShape.love: return const _HeartClipper();
    case PhotoShape.abstrak: return const _BlobClipper();
    case PhotoShape.bunga: return const _FlowerClipper();
    case PhotoShape.bulat: return const _CircleClipper();
    case PhotoShape.hexagon: return const _HexagonClipper();
    case PhotoShape.diamond: return const _DiamondClipper();
    case PhotoShape.star: return const _StarClipper();
    case PhotoShape.heart2: return const _Heart2Clipper();
  }
}

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
      case PhotoShape.hexagon:
        return const _HexagonClipper();
      case PhotoShape.diamond:
        return const _DiamondClipper();
      case PhotoShape.star:
        return const _StarClipper();
      case PhotoShape.heart2:
        return const _Heart2Clipper();
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

// ===== FIX #17: 4 bentuk tambahan =====
class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();
  @override
  Path getClip(Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.shortestSide / 2;
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 2;
      final x = cx + r * math.cos(a), y = cy + r * math.sin(a);
      if (i == 0) p.moveTo(x, y); else p.lineTo(x, y);
    }
    p.close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiamondClipper extends CustomClipper<Path> {
  const _DiamondClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _StarClipper extends CustomClipper<Path> {
  const _StarClipper();
  @override
  Path getClip(Size size) {
    final cx = size.width / 2, cy = size.height / 2, R = size.shortestSide / 2, r = R * 0.45;
    const points = 5;
    final p = Path();
    for (int i = 0; i < points * 2; i++) {
      final rad = i.isEven ? R : r;
      final a = math.pi / points * i - math.pi / 2;
      final x = cx + rad * math.cos(a), y = cy + rad * math.sin(a);
      if (i == 0) p.moveTo(x, y); else p.lineTo(x, y);
    }
    p.close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Heart2Clipper extends CustomClipper<Path> {
  const _Heart2Clipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path();
    p.moveTo(w * 0.5, h * 0.12);
    p.cubicTo(w * 0.5, h * 0.04, w * 0.8, h * 0.0, w * 0.92, h * 0.22);
    p.cubicTo(w, h * 0.42, w * 0.76, h * 0.68, w * 0.5, h * 0.96);
    p.cubicTo(w * 0.24, h * 0.68, w * 0.0, h * 0.42, w * 0.08, h * 0.22);
    p.cubicTo(w * 0.2, h * 0.0, w * 0.5, h * 0.04, w * 0.5, h * 0.12);
    p.close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
