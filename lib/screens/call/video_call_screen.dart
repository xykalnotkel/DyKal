import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  // BATCH G: bukan lagi `final ... = DyKalCallService()` — saat rejoin dari
  // bar "kembali ke panggilan" kita MENEMPEL ke sesi hidup (current).
  late DyKalCallService call;
  bool _rejoin = false;
  Timer? _timer;
  int _elapsed = 0;
  String _filter = 'none';
  bool _swapped = false;
  bool _isCaller = true;

  // Posisi PIP (bisa digeser)
  double _pipTop = 60;
  double _pipRight = 16;

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
    _isCaller = isCaller == true;

    // REJOIN: ada sesi hidup dengan tipe sama -> tempel, jangan telpon ulang.
    final existing = DyKalCallService.current;
    if (existing != null && existing.sessionActive && existing.callType == type) {
      call = existing;
      _rejoin = true;
      _isCaller = existing.isCaller;
      call.addListener(_onChanged);
      final at = existing.answeredAt;
      if (at != null) {
        _elapsed = DateTime.now().difference(at).inSeconds;
      }
      _onChanged(); // bind stream langsung
      _startTimer();
      return;
    }

    call = DyKalCallService();
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

    _startTimer();
  }

  void _startTimer() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  /// Status panggilan yang akurat: Memanggil / Berdering / Tersambung.
  String get _callStatus {
    if (call.connected) return 'Tersambung';
    return _isCaller ? 'Memanggil...' : 'Berdering...';
  }

  /// Buka panel kontrol (filter video).
  void _openControlPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kontrol Panggilan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('Filter Video', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _panelChip('none', 'Normal', Icons.auto_awesome),
                  _panelChip('warm', 'Warm', Icons.wb_sunny),
                  _panelChip('cool', 'Cool', Icons.ac_unit),
                  _panelChip('bw', 'B&W', Icons.dark_mode),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Volume speaker diatur lewat tombol speaker. Gain mikrofon tidak didukung langsung oleh WebRTC di Android.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelChip(String id, String label, IconData icon) {
    final active = _filter == id;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = id);
        call.setMyFilter(id);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? DyKalTheme.primary : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? DyKalTheme.primary : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// Placeholder saat kamera mati: foto profil + nama + blur + gelombang suara.
  Widget _cameraOffPlaceholder({required bool isLocal, required bool muted}) {
    final name = isLocal ? AuthService().myName : (AuthService().partnerName ?? 'Pasangan');
    final photo = isLocal ? AuthService().myPhotoUrl : AuthService().partnerPhotoUrl;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A2438), Color(0xFF1F2029)]),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blur background dari foto profil (atau gradasi)
          if (photo != null && photo.isNotEmpty)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: DyKalTheme.primary.withValues(alpha: 0.25),
                  backgroundImage: (photo != null && photo.isNotEmpty) ? CachedNetworkImageProvider(photo) : null,
                  child: (photo == null || photo.isEmpty)
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _VoiceWave(muted: muted, color: DyKalTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
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
    // BATCH G: kalau instance ini masih sesi HIDUP (user hanya mengecilkan
    // layar), JANGAN dimatikan — panggilan lanjut, bar "kembali ke
    // panggilan" tampil. Sesi hanya mati via tombol merah / lawan menutup.
    if (!identical(call, DyKalCallService.current) && !_rejoin) {
      call.dispose();
    }
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
    final bigIsLocal = _swapped;
    final bigIsRemote = !bigIsLocal;
    final bigFilter = bigIsLocal ? _filter : call.peerFilter;
    final pipFilter = bigIsLocal ? call.peerFilter : _filter;
    final fc = _filterColor(bigFilter);
    final pipFc = _filterColor(pipFilter);

    // Kamera mati (lokal) -> placeholder foto + nama + blur + gelombang, bukan hitam
    final localCameraOff = bigIsLocal && !call.videoOn;
    final showWaiting = bigIsRemote && call.remoteStream == null;

    return Scaffold(
      backgroundColor: DyKalTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Layar Penuh (atau placeholder kamera mati)
            Positioned.fill(
              child: localCameraOff
                  ? _cameraOffPlaceholder(isLocal: true, muted: call.muted)
                  : (showWaiting
                      ? _cameraOffPlaceholder(isLocal: false, muted: false)
                      : (fc == null
                          ? RTCVideoView(_swapped ? _local : _remote,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              mirror: bigIsLocal)
                          : ColorFiltered(
                              colorFilter: fc,
                              child: RTCVideoView(_swapped ? _local : _remote,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  mirror: bigIsLocal),
                            ))),
            ),

            // Badge status panggilan (Memanggil... / Berdering... / Tersambung)
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: call.connected ? DyKalTheme.online : DyKalTheme.primary),
                  const SizedBox(width: 6),
                  Text(_callStatus, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

            // BATCH G: chevron KECILKAN — panggilan lanjut di latar,
            // bar hijau "kembali ke panggilan" muncul di layar utama.
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
              ),
            ),

            // Picture-in-Picture (bisa digeser; ketuk untuk swap besar/kecil)
            Positioned(
              top: _pipTop,
              right: _pipRight,
              child: GestureDetector(
                onTap: () => setState(() => _swapped = !_swapped),
                onPanUpdate: (d) {
                  setState(() {
                    _pipTop = (_pipTop + d.delta.dy).clamp(10.0, 700.0);
                    _pipRight = (_pipRight - d.delta.dx).clamp(10.0, 300.0);
                  });
                },
                child: Container(
                  width: 105,
                  height: 155,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (bigIsRemote && !call.videoOn)
                      ? _cameraOffPlaceholder(isLocal: true, muted: call.muted)
                      : (pipFc == null
                          ? RTCVideoView(_swapped ? _remote : _local,
                              mirror: !bigIsLocal,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                          : ColorFiltered(
                              colorFilter: pipFc,
                              child: RTCVideoView(_swapped ? _remote : _local,
                                  mirror: !bigIsLocal,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                            )),
                ),
              ),
            ),

            // Kontrol Bawah (filter & volume di dalam menu kontrol)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                children: [
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
                      _btn(Icons.filter_alt_outlined, _filter != 'none', _openControlPanel),
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

/// Gelombang suara animasi — tampil saat kamera mati sebagai pengganti video.
class _VoiceWave extends StatefulWidget {
  final bool muted;
  final Color color;
  const _VoiceWave({required this.muted, required this.color});

  @override
  State<_VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<_VoiceWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<Animation<double>> _bars;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _bars = List.generate(5, (i) {
      final start = i * 0.08;
      return Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _c,
          curve: Interval(start, start + 0.5, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          final h = widget.muted ? 4.0 : (10 + _bars[i].value * 18);
          return Container(
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: widget.muted ? Colors.white38 : widget.color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
