import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/ringtone_player.dart';

/// Layar panggilan masuk. Tombol Angkat/Tolak di-SWIPE ke atas + animasi melayang.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with TickerProviderStateMixin {
  String _type = 'video';
  String _callerName = '';
  StreamSubscription? _sub;
  final call = DyKalCallService();
  bool _gone = false;

  late final AnimationController _float; // animasi naik-turun tombol
  late final AnimationController _pulse; // animasi avatar

  @override
  void initState() {
    super.initState();
    _type = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'video';
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    RingtonePlayer.start();
    final coupleId = AuthService().coupleId ?? '';
    _sub = FirebaseFirestore.instance.doc('calls/$coupleId').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null || data['status'] == 'ended') {
        if (!_gone) { _gone = true; Navigator.pop(context); }
        return;
      }
      if (mounted) setState(() {
        _type = (data['type'] as String?) ?? 'video';
        _callerName = (data['callerName'] as String?) ?? '';
      });
    });
  }

  @override
  void dispose() {
    RingtonePlayer.stop();
    _sub?.cancel();
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _accept() {
    if (_gone) return;
    _gone = true;
    _sub?.cancel();
    final route = _type == 'video' ? '/videoCall' : '/audioCall';
    Navigator.of(context).pushReplacementNamed(route, arguments: {'isCaller': false, 'type': _type});
  }

  void _decline() async {
    if (_gone) return;
    _gone = true;
    await call.declineIncoming();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      body: SafeArea(child: Column(children: [
        const Spacer(flex: 2),
        // Avatar berdenyut
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient, boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.5), blurRadius: 40)]),
            child: Center(child: Text(_callerName.isNotEmpty ? _callerName[0] : '?', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 18),
        Text(_callerName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_type == 'video' ? Icons.videocam : Icons.call, color: DyKalTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(_type == 'video' ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        const Spacer(flex: 2),
        // Dua tombol swipe-ke-atas (melayang naik-turun)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _SwipeAction(
              floatAnim: _float,
              color: Colors.red,
              icon: Icons.call_end,
              label: 'Tolak',
              hint: 'Geser ke atas',
              onTrigger: _decline,
            ),
            _SwipeAction(
              floatAnim: _float,
              color: DyKalTheme.online,
              icon: Icons.call,
              label: 'Angkat',
              hint: 'Geser ke atas',
              onTrigger: _accept,
            ),
          ]),
        ),
      ])),
    );
  }
}

/// Tombol bulat yang bisa di-swipe ke atas untuk memicu aksi + animasi melayang.
class _SwipeAction extends StatefulWidget {
  final Animation<double> floatAnim;
  final Color color;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTrigger;
  const _SwipeAction({required this.floatAnim, required this.color, required this.icon, required this.label, required this.hint, required this.onTrigger});

  @override
  State<_SwipeAction> createState() => _SwipeActionState();
}

class _SwipeActionState extends State<_SwipeAction> {
  double _dy = 0; // offset drag vertikal (negatif = ke atas)
  static const _threshold = 90;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Petunjuk arah
      Opacity(
        opacity: 0.7,
        child: Icon(Icons.keyboard_arrow_up, color: widget.color, size: 22),
      ),
      const SizedBox(height: 4),
      GestureDetector(
        onVerticalDragUpdate: (d) => setState(() => _dy += d.delta.dy),
        onVerticalDragEnd: (_) {
          if (_dy <= -_threshold) {
            widget.onTrigger();
          }
          setState(() => _dy = 0);
        },
        child: AnimatedBuilder(
          animation: widget.floatAnim,
          builder: (_, __) {
            // melayang naik-turun dikit + ikuti drag
            final float = (widget.floatAnim.value - 0.5) * 10; // -5..5
            return Transform.translate(
              offset: Offset(0, _dy + float),
              child: Container(
                width: 78, height: 78,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 6))]),
                child: Icon(widget.icon, color: Colors.white, size: 32),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      Text(widget.hint, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]);
  }
}
