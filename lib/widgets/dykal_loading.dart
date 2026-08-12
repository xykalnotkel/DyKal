import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Paket loading/placeholder bermerek DyKal (Batch: "custom loading semua").
/// Satu sumber untuk spinner, shimmer skeleton, dan state error dengan retry —
/// jangan lagi pakai CircularProgressIndicator polos di layar baru.

/// Spinner bermerek: hati berdenyut scale in/out (bukan roda generik).
class DyKalSpinner extends StatefulWidget {
  final double size;
  const DyKalSpinner({super.key, this.size = 34});

  @override
  State<DyKalSpinner> createState() => _DyKalSpinnerState();
}

class _DyKalSpinnerState extends State<DyKalSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform.scale(
            scale: 0.82 + t * 0.28,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: DyKalTheme.dykalGradient,
                borderRadius: BorderRadius.circular(widget.size * 0.32),
                boxShadow: [
                  BoxShadow(
                    color: DyKalTheme.primary.withValues(alpha: 0.3 + t * 0.25),
                    blurRadius: 10 + t * 10,
                  ),
                ],
              ),
              child: Icon(Icons.favorite, color: Colors.white, size: widget.size * 0.52),
            ),
          );
        },
      ),
    );
  }
}

/// Kotak skeleton dengan sapuan shimmer — untuk thumbnail gambar/kartu.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  const ShimmerBox({super.key, this.width, this.height, this.radius = 12});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF26262E) : const Color(0xFFE8E4EA);
    final shine = dark ? const Color(0xFF3A3A44) : const Color(0xFFF7F3F6);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + t * 2.4, 0),
              end: Alignment(-0.2 + t * 2.4, 0),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// Barisan skeleton bergaya ListTile (avatar + 2 baris teks).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ShimmerBox(width: 44, height: 44, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 12, width: 140),
                SizedBox(height: 6),
                ShimmerBox(height: 10, width: 210),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// State error bermerek: ikon, pesan, tombol coba lagi.
class DyKalErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const DyKalErrorView({super.key, this.message = 'Terjadi kesalahan', this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DyKalTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.heart_broken_outlined, color: DyKalTheme.primary, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: DyKalTheme.textSecondaryOf(context)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
