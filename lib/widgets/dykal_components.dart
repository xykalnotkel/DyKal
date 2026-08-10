import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

class DyKalSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const DyKalSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1F2029) : const Color(0xFFEBEBF0),
      highlightColor: isDark ? const Color(0xFF2D303E) : const Color(0xFFF5F5FA),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2029) : const Color(0xFFEBEBF0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class DyKalImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  const DyKalImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 16,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => DyKalSkeleton(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          radius: radius,
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Theme.of(context).brightness == Brightness.dark
              ? DyKalTheme.surfaceDark
              : Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class DyKalButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  const DyKalButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? DyKalTheme.primary;
    return SizedBox(
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: foregroundColor ?? Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}
