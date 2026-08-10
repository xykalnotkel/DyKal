import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/ringtone_player.dart';

/// Layar panggilan masuk: Swipe-to-answer/decline dengan animasi visual modern
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
  bool _initializedArgs = false;

  late final AnimationController _float;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    RingtonePlayer.start();
    
    final coupleId = AuthService().coupleId ?? '';
    _sub = FirebaseFirestore.instance.doc('calls/$coupleId').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null || data['status'] == 'ended') {
        if (!_gone) {
          _gone = true;
          Navigator.pop(context);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _type = (data['type'] as String?) ?? 'video';
          _callerName = (data['callerName'] as String?) ?? '';
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _type = args;
      } else if (args is Map<String, dynamic>) {
        _type = args['type'] ?? 'video';
      }
    }
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
      backgroundColor: DyKalTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/backgrounds/call_bg_dark.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Container(color: Colors.black.withValues(alpha: 0.4)),
            Column(
          children: [
            const Spacer(flex: 2),
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DyKalTheme.dykalGradient,
                  boxShadow: [
                    BoxShadow(
                      color: DyKalTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _callerName.isNotEmpty ? _callerName[0] : '?',
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _callerName.isNotEmpty ? _callerName : 'Pasangan Kamu',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_type == 'video' ? Icons.videocam : Icons.call, color: DyKalTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  _type == 'video' ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk',
                  style: const TextStyle(color: DyKalTheme.textMutedDark, fontSize: 14),
                ),
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SwipeAction(
                    floatAnim: _float,
                    color: Colors.redAccent,
                    icon: Icons.call_end,
                    label: 'Tolak',
                    onTrigger: _decline,
                  ),
                  _SwipeAction(
                    floatAnim: _float,
                    color: DyKalTheme.online,
                    icon: Icons.call,
                    label: 'Angkat',
                    onTrigger: _accept,
                  ),
                ],
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatefulWidget {
  final Animation<double> floatAnim;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTrigger;

  const _SwipeAction({
    required this.floatAnim,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTrigger,
  });

  @override
  State<_SwipeAction> createState() => _SwipeActionState();
}

class _SwipeActionState extends State<_SwipeAction> {
  double _dy = 0;
  static const _threshold = 80;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              final float = (widget.floatAnim.value - 0.5) * 8;
              return Transform.translate(
                offset: Offset(0, _dy + float),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 30),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
