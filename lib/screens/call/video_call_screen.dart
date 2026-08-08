import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../config/theme.dart';
import '../../services/call_service.dart';
import '../../services/auth_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  final call = DyKalCallService();
  Timer? _timer;
  int _elapsed = 0;
  String _filter = 'none';
  bool _started = false;
  bool _swapped = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _local.initialize();
    await _remote.initialize();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isCaller = args?['isCaller'] ?? true;
    final type = args?['type'] ?? 'video';

    call.addListener(_onChanged);
    try {
      if (isCaller == true) {
        await call.startOutgoing(type);
      } else {
        await call.acceptIncoming();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memulai panggilan: $e')));
        Navigator.pop(context);
      }
      return;
    }
    if (mounted) {
      setState(() => _started = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    }
  }

  void _onChanged() {
    if (!mounted) return;
    _local.srcObject = call.localStream;
    _remote.srcObject = call.remoteStream;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    call.removeListener(_onChanged);
    call.dispose();
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  String get _time {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  ColorFilter? _filterColor(String f) {
    switch (f) {
      case 'warm': return ColorFilter.mode(const Color(0xFFFFE0B2).withOpacity(0.3), BlendMode.overlay);
      case 'cool': return ColorFilter.mode(const Color(0xFFB2EBF2).withOpacity(0.25), BlendMode.overlay);
      case 'bw': return const ColorFilter.matrix(<double>[
        0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0,
      ]);
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bigRenderer = _swapped ? _local : _remote;
    final pipRenderer = _swapped ? _remote : _local;
    final bigIsLocal = _swapped;
    final bigFilter = bigIsLocal ? _filter : call.peerFilter;
    final pipFilter = bigIsLocal ? call.peerFilter : _filter;
    final fc = _filterColor(bigFilter);
    final pipFc = _filterColor(pipFilter);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      body: SafeArea(child: Stack(children: [
        // Tampilan besar (remote atau local kalau ditukar)
        Positioned.fill(child: fc == null
          ? RTCVideoView(bigRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: bigIsLocal)
          : ColorFiltered(colorFilter: fc, child: RTCVideoView(bigRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: bigIsLocal))),
        if (!_swapped && call.remoteStream == null)
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 120, height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient),
              child: const Center(child: Icon(Icons.videocam, color: Colors.white, size: 40))),
            const SizedBox(height: 16),
            Text(AuthService().partnerName ?? 'Ayang', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('presence/${AuthService().partnerId}').snapshots(),
              builder: (_, snap) {
                final online = (snap.data?.data() as Map<String, dynamic>?)?['isOnline'] ?? false;
                final status = call.connected ? 'Terhubung...' : (online ? 'Berdering...' : 'Memanggil...');
                return Text(status, style: const TextStyle(color: Colors.white70, fontSize: 13));
              },
            ),
          ])),

        // Picture-in-picture (ketuk untuk tukar posisi)
        Positioned(top: 48, right: 16, child: GestureDetector(
          onTap: () => setState(() => _swapped = !_swapped),
          child: Container(
            width: 110, height: 160,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white54, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: pipFc == null
              ? RTCVideoView(pipRenderer, mirror: !bigIsLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : ColorFiltered(colorFilter: pipFc, child: RTCVideoView(pipRenderer, mirror: !bigIsLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
          ),
        )),

        // Filter chips
        Positioned(left: 0, right: 0, bottom: 140, child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _chip('none', 'Normal', Icons.auto_awesome),
            _chip('warm', 'Warm', Icons.wb_sunny),
            _chip('cool', 'Cool', Icons.ac_unit),
            _chip('bw', 'B&W', Icons.dark_mode),
          ]),
        )),

        // Kontrol bawah
        Positioned(left: 0, right: 0, bottom: 36, child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(_time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ])),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _btn(Icons.mic_off, call.muted, call.toggleMute),
            _btn(Icons.videocam_off, !call.videoOn, call.toggleVideo),
            _btn(Icons.swap_horiz, _swapped, () => setState(() => _swapped = !_swapped)),
            _btn(Icons.volume_up, call.speakerOn, () => call.toggleSpeaker()),
          ]),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () { call.hangUp(); Navigator.pop(context); },
            child: Container(width: 68, height: 68, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.call_end, color: Colors.white, size: 28)),
          ),
        ])),
      ])),
    );
  }

  Widget _chip(String id, String label, IconData icon) {
    final active = _filter == id;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _filter = id); call.setMyFilter(id); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [Icon(icon, size: 14, color: active ? Colors.white : Colors.white70), const SizedBox(width: 6), Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))]),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 56, height: 56, decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.white.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22)),
    );
  }
}
