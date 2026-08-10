import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

class StoryAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final int storyCount;
  final bool allSeen;
  final VoidCallback onTap;
  final double size;

  const StoryAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    required this.storyCount,
    required this.allSeen,
    required this.onTap,
    this.size = 68,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = allSeen
        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF555865) : const Color(0xFFBDC1C6))
        : DyKalTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _SegmentedBorderPainter(
          segmentCount: storyCount > 0 ? storyCount : 1,
          color: borderColor,
          strokeWidth: 2.5,
          gapSize: storyCount > 1 ? 0.12 : 0.0,
        ),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4.5),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: DyKalTheme.cardOf(context)),
                    errorWidget: (_, __, ___) => _fallbackAvatar(),
                  )
                : _fallbackAvatar(),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: DyKalTheme.dykalGradient,
      ),
      child: Center(
        child: Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
    );
  }
}

class _SegmentedBorderPainter extends CustomPainter {
  final int segmentCount;
  final Color color;
  final double strokeWidth;
  final double gapSize;

  _SegmentedBorderPainter({
    required this.segmentCount,
    required this.color,
    required this.strokeWidth,
    required this.gapSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segmentCount <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    if (segmentCount == 1) {
      canvas.drawOval(rect, paint);
      return;
    }

    final totalAngle = 2 * math.pi;
    final totalGapAngle = segmentCount * gapSize;
    final arcAngle = (totalAngle - totalGapAngle) / segmentCount;

    double startAngle = -math.pi / 2 + gapSize / 2;

    for (int i = 0; i < segmentCount; i++) {
      canvas.drawArc(rect, startAngle, arcAngle, false, paint);
      startAngle += arcAngle + gapSize;
    }
  }

  @override
  bool shouldRepaint(_SegmentedBorderPainter oldDelegate) {
    return oldDelegate.segmentCount != segmentCount ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapSize != gapSize;
  }
}
