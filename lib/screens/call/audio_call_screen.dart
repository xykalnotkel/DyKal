import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/call_service.dart';
import '../../services/auth_service.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key});
  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  final call = DyKalCallService();
  Timer? _timer;
  int _elapsed = 0;
  double volume = 0.8;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isCaller = args?['isCaller'] ?? true;
    call.addListener(() => setState(() {}));
    try {
      if (isCaller == true) {
        await call.startOutgoing('audio');
      } else {
        await call.acceptIncoming();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        Navigator.pop(context);
      }
      return;
    }
    if (mounted) _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    call.removeListener(() {});
    call.dispose();
    super.dispose();
  }

  String get _time {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconButton(onPressed: () { call.hangUp(); Navigator.pop(context); }, icon: const Icon(Icons.expand_more, color: Colors.white)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [Icon(Icons.access_time, color: Colors.white70, size: 14), const SizedBox(width: 6), Text(_time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])),
          ]),
        ),
        const Spacer(),
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient, boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.4), blurRadius: 30)]),
          child: Center(child: Text((AuthService().partnerName ?? '?').isNotEmpty ? (AuthService().partnerName ?? '?')[0] : '?', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(height: 16),
        Text(AuthService().partnerName ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.graphic_eq, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(call.connected ? 'Tersambung • HD Voice' : 'Memanggil...', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
        const SizedBox(height: 24),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.volume_up, color: Colors.white, size: 20),
            Expanded(child: Slider(value: volume, min: 0, max: 1, activeColor: DyKalTheme.primary, inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => volume = v))),
            const Icon(Icons.volume_down, color: Colors.white70, size: 16),
          ]),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn(Icons.mic_off, call.muted, 'Mute', call.toggleMute),
              _btn(Icons.volume_up, call.speakerOn, 'Speaker', () => call.toggleSpeaker()),
              _btn(Icons.videocam, false, 'Video', () async {
                await call.hangUp();
                if (mounted) Navigator.pushReplacementNamed(context, '/videoCall', arguments: {'isCaller': true, 'type': 'video'});
              }),
            ]),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { call.hangUp(); Navigator.pop(context); },
              child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 28)),
            ),
          ]),
        ),
      ])),
    );
  }

  Widget _btn(IconData icon, bool active, String label, VoidCallback onTap) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Container(width: 56, height: 56, decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22)),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}
