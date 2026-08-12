import 'package:flutter/material.dart';
import '../services/call_service.dart';

/// Bar hijau BERKEDIP ala WhatsApp (spek v2 #5B) — muncul di paling atas
/// saat ada panggilan aktif namun user mengecilkan layar panggilan.
/// Ketuk -> kembali ke layar panggilan yang sedang berjalan (rejoin sesi,
/// BUKAN menelpon ulang — layar memakai DyKalCallService.current).
class ReturnToCallBar extends StatefulWidget {
  const ReturnToCallBar({super.key});

  @override
  State<ReturnToCallBar> createState() => _ReturnToCallBarState();
}

class _ReturnToCallBarState extends State<ReturnToCallBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _rejoinCall(BuildContext context) {
    final type = DyKalCallService.activeCallType;
    final isCaller = DyKalCallService.current?.isCaller ?? true;
    Navigator.of(context).pushNamed(
      type == 'audio' ? '/audioCall' : '/videoCall',
      arguments: {'isCaller': isCaller, 'type': type},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DyKalCallService.inCall,
      builder: (context, inCall, _) {
        if (!inCall) return const SizedBox.shrink();
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: () => _rejoinCall(context),
              child: FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.55).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  color: const Color(0xFF075E54),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        DyKalCallService.activeCallType == 'audio' ? Icons.call : Icons.videocam,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ketuk untuk kembali ke panggilan...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
