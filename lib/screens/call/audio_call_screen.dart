import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/call_service.dart';
import '../../services/auth_service.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key});

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  // BATCH G: late — rejoin menempel ke DyKalCallService.current, bukan sesi baru.
  late DyKalCallService call;
  bool _rejoin = false;
  bool _attached = false; // call sudah ter-assign & listener terpasang
  Timer? _timer;
  int _elapsed = 0;
  double volume = 0.8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isCaller = args?['isCaller'] ?? true;

    // REJOIN: ada sesi audio hidup -> tempel, jangan telpon ulang.
    final existing = DyKalCallService.current;
    if (existing != null && existing.sessionActive && existing.callType == 'audio') {
      call = existing;
      _rejoin = true;
      call.addListener(_onStateChanged);
      _attached = true;
      if (mounted) setState(() {});
      final at = existing.answeredAt;
      if (at != null) {
        _elapsed = DateTime.now().difference(at).inSeconds;
      }
      _onStateChanged();
      _startTimer();
      return;
    }

    call = DyKalCallService();
    call.addListener(_onStateChanged);
    _attached = true;
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
    _startTimer();
  }

  void _startTimer() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _safePop() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (call.endedByRemote) {
      _safePop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_attached) {
      call.removeListener(_onStateChanged);
      // BATCH G: sesi hidup (DyKalCallService.current) jangan dibunuh saat
      // layar cuma dikecilkan.
      if (!identical(call, DyKalCallService.current) && !_rejoin) {
        call.dispose();
      }
    }
    super.dispose();
  }

  String get timeFormatted {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Tulis riwayat panggilan ke chat (type system) — setara video call.
  Future<void> _endCallLog() async {
    final coupleId = AuthService().coupleId ?? '';
    if (coupleId.isEmpty) return;
    final connected = call.remoteStream != null;
    final text = connected ? 'Panggilan suara ($timeFormatted)' : 'Panggilan suara tidak terjawab';
    try {
      await FirebaseFirestore.instance.collection('chats/$coupleId/messages').add({
        'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
        'fromId': AuthService().myId,
        'toId': '',
        'text': text,
        'type': 'system',
        'status': 'read',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = AuthService().partnerName ?? 'Pasangan';
    // `call` late — guard frame pertama sebelum _init menempelkan sesi.
    if (!_attached) {
      return const Scaffold(
        backgroundColor: DyKalTheme.backgroundDark,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: DyKalTheme.primary))),
      );
    }
    return Scaffold(
      backgroundColor: DyKalTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background panggilan dari aset (tema gelap)
            Image.asset(
              'assets/backgrounds/call_bg_dark.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            Column(
              children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    // BATCH G: chevron = KECILKAN panggilan (lanjut di
                    // latar, bar hijau "kembali ke panggilan" muncul) —
                    // bukan mematikan. Tombol merah di bawah yang mematikan.
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          timeFormatted,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DyKalTheme.dykalGradient,
                boxShadow: [
                  BoxShadow(
                    color: DyKalTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  partnerName.isNotEmpty ? partnerName[0] : '?',
                  style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              partnerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.graphic_eq, color: DyKalTheme.online, size: 16),
                const SizedBox(width: 6),
                Text(
                  // BATCH H: bahasa manusia, bukan bahasa mesin ("Menghubungkan").
                  call.connected
                      ? 'Tersambung • HD Voice'
                      : (call.isCaller ? 'Memanggil...' : 'Menyambungkan...'),
                  style: const TextStyle(color: DyKalTheme.textMutedDark, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: DyKalTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DyKalTheme.borderSoftDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volume_down, color: Colors.white70, size: 18),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      activeColor: DyKalTheme.primary,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => setState(() => volume = v),
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Colors.white, size: 20),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _btn(Icons.mic_off, call.muted, 'Mute', call.toggleMute),
                      _btn(Icons.volume_up, call.speakerOn, 'Speaker', () => call.toggleSpeaker()),
                      _btn(Icons.videocam, false, 'Video', () async {
                        await call.upgradeToVideo();
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                            context,
                            '/videoCall',
                            arguments: {'isCaller': call.isCaller, 'type': 'video'},
                          );
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      _endCallLog();
                      call.hangUp();
                      _safePop();
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
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

  Widget _btn(IconData icon, bool active, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: active ? DyKalTheme.primary : DyKalTheme.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(color: active ? DyKalTheme.primary : DyKalTheme.borderSoftDark),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: DyKalTheme.textMutedDark, fontSize: 12)),
      ],
    );
  }
}
