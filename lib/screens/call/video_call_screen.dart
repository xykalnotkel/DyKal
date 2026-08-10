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
  bool _swapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _local.initialize();
    await _remote.initialize();
    if (!mounted) return;

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
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed++);
      });
    }
  }

  Future<void> _endCallLog() async {
    final coupleId = AuthService().coupleId ?? '';
    if (coupleId.isEmpty) return;
    final connected = call.remoteStream != null;
    final text = connected ? 'Panggilan video ($timeFormatted)' : 'Panggilan video tidak terjawab';
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

  String get timeFormatted {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  ColorFilter? _filterColor(String f) {
    switch (f) {
      case 'warm':
        return ColorFilter.mode(const Color(0xFFFFE0B2).withValues(alpha: 0.3), BlendMode.overlay);
      case 'cool':
        return ColorFilter.mode(const Color(0xFFB2EBF2).withValues(alpha: 0.25), BlendMode.overlay);
      case 'bw':
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
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
      backgroundColor: DyKalTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Layar Penuh
            Positioned.fill(
              child: fc == null
                  ? RTCVideoView(bigRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: bigIsLocal)
                  : ColorFiltered(
                      colorFilter: fc,
                      child: RTCVideoView(bigRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: bigIsLocal),
                    ),
            ),

            // Waiting State jika remote stream belum masuk
            if (!_swapped && call.remoteStream == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient),
                      child: const Center(child: Icon(Icons.videocam, color: Colors.white, size: 40)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AuthService().partnerName ?? 'Pasangan',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.doc('presence/${AuthService().partnerId}').snapshots(),
                      builder: (_, snap) {
                        final online = (snap.data?.data() as Map<String, dynamic>?)?['isOnline'] ?? false;
                        final status = call.connected
                            ? 'Terhubung...'
                            : (online ? 'Berdering...' : 'Memanggil...');
                        return Text(status, style: const TextStyle(color: DyKalTheme.textMutedDark, fontSize: 13));
                      },
                    ),
                  ],
                ),
              ),

            // Picture-in-Picture (PiP)
            Positioned(
              top: 60,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _swapped = !_swapped),
                child: Container(
                  width: 105,
                  height: 155,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: pipFc == null
                      ? RTCVideoView(pipRenderer, mirror: !bigIsLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      : ColorFiltered(
                          colorFilter: pipFc,
                          child: RTCVideoView(pipRenderer, mirror: !bigIsLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                        ),
                ),
              ),
            ),

            // Kontrol Bawah & Filter Chips
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                children: [
                  // Filter Chips (di atas kontrol bawah)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chip('none', 'Normal', Icons.auto_awesome),
                        _chip('warm', 'Warm', Icons.wb_sunny),
                        _chip('cool', 'Cool', Icons.ac_unit),
                        _chip('bw', 'B&W', Icons.dark_mode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Text(timeFormatted, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _btn(Icons.mic_off, call.muted, call.toggleMute),
                      _btn(Icons.videocam_off, !call.videoOn, call.toggleVideo),
                      _btn(Icons.swap_horiz, _swapped, () => setState(() => _swapped = !_swapped)),
                      _btn(Icons.cameraswitch, false, () => call.flipCamera()),
                      _btn(Icons.screen_share, call.screenSharing, () async {
                        final ok = await call.toggleScreenShare();
                        if (!mounted) return;
                        if (!ok && call.lastError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(call.lastError!)));
                        }
                      }),
                      _btn(Icons.volume_up, call.speakerOn, () => call.toggleSpeaker()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      _endCallLog();
                      call.hangUp();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String id, String label, IconData icon) {
    final active = _filter == id;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _filter = id);
          call.setMyFilter(id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? DyKalTheme.primary : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? DyKalTheme.primary : Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? DyKalTheme.primary : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
