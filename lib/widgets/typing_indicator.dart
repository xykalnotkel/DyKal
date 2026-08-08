import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Indikator "sedang mengetik..." 3 titik bulat beranimasi (gaya WhatsApp).
class TypingDots extends StatefulWidget {
  final Color? color;
  const TypingDots({super.key, this.color});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _cs;

  @override
  void initState() {
    super.initState();
    _cs = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _cs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DyKalTheme.primary;
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: ScaleTransition(
          scale: Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _cs[i], curve: Curves.easeInOut)),
          child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
      );
    }));
  }
}
