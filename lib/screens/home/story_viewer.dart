import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../config/theme.dart';

class StoryViewer extends StatefulWidget {
  final String coupleId;
  const StoryViewer({super.key, required this.coupleId});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  final _audioPlayer = AudioPlayer();
  List<String> _photoUrls = [];
  List<String> _audioPaths = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _error; // FIX: dulu error -> loading muter SELAMANYA (layar hitam)

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _audioPaths = prefs.getStringList('story_audio_playlist') ?? [];

      // Timeout 12 dtk: jaringan jelek/rules error = tampilkan pesan, bukan
      // spinner abadi (akar laporan owner: "loading trus background hitam")
      final albumsSnap = await FirebaseFirestore.instance
          .collection('couples/${widget.coupleId}/albums')
          .get()
          .timeout(const Duration(seconds: 12));

      for (final album in albumsSnap.docs) {
        final photosSnap = await FirebaseFirestore.instance
            .collection('couples/${widget.coupleId}/albums/${album.id}/photos')
            .limit(6)
            .get()
            .timeout(const Duration(seconds: 12));
        for (final p in photosSnap.docs) {
          final url = p.data()['url'] as String?;
          if (url != null) _photoUrls.add(url);
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    if (_photoUrls.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _photoUrls.shuffle();

    if (_audioPaths.isNotEmpty) {
      final randomPath = (_audioPaths..shuffle()).first;
      try {
        await _audioPlayer.setFilePath(randomPath);
        // BATCH H: musik fade-in halus (menyesuaikan suasana — tidak nyentak).
        await _audioPlayer.setVolume(0.0);
        await _audioPlayer.play();
        _startFadeIn();
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loading = false);
      _animController.forward();
    }
  }

  Timer? _fadeTimer;

  /// Volume naik pelan 0 -> 0.65 dalam ~1 detik.
  void _startFadeIn() {
    _fadeTimer?.cancel();
    var step = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      step++;
      _audioPlayer.setVolume((0.65 * step / 12).clamp(0.0, 0.65));
      if (step >= 12) t.cancel();
    });
  }

  void _nextStory() {
    if (_currentIndex < _photoUrls.length - 1) {
      setState(() {
        _currentIndex++;
        _animController.reset();
        _animController.forward();
      });
    } else {
      // BATCH H (owner): deck habis -> ACAK ULANG & PUTAR LAGI (revert terus
      // "sampai ada stock lain"), bukan langsung menutup cerita.
      setState(() {
        _photoUrls.shuffle();
        _currentIndex = 0;
        _animController.reset();
        _animController.forward();
      });
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _animController.reset();
        _animController.forward();
      });
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  bool _paused = false;

  void _pause() {
    _animController.stop();
    _audioPlayer.pause();
    if (mounted) setState(() => _paused = true);
  }

  void _resume() {
    _animController.forward();
    _audioPlayer.play();
    if (mounted) setState(() => _paused = false);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: DyKalTheme.primary),
        ),
      );
    }

    if (_photoUrls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _error != null ? Icons.cloud_off_rounded : Icons.photo_library_outlined,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error != null ? 'Gagal memuat cerita' : 'Belum ada foto di album',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Cek koneksi internet, lalu coba lagi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ),
              ],
              const SizedBox(height: 8),
              if (_error != null)
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                      _photoUrls = [];
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onLongPressCancel: () => _resume(),
        // Pakai onTapUp (bukan onTapDown) agar menahan jari tidak langsung
        // memindah story — sentuhan diam = pause (long press).
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // BATCH H: latar hitam diganti PREVIEW BLUR dari foto yang sedang
            // tampil (ala IG) — layar tak pernah kosong hitam, sekaligus jadi
            // "preview loading" saat gambar utama masih memuat.
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: CachedNetworkImage(
                  imageUrl: _photoUrls[_currentIndex],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
            ),
            // Lapisan gelap tipis agar foto utama tetap fokus
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),

            // Foto utama (contain, utuh tak terpotong)
            Center(
              child: CachedNetworkImage(
                imageUrl: _photoUrls[_currentIndex],
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(), // blur sudah jadi preview
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
            ),

            // Indikator pause saat ditahan
            if (_paused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.pause, color: Colors.white, size: 32),
                ),
              ),

            // Top Segmented Progress Bars
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(_photoUrls.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, _) {
                                double progress = 0.0;
                                if (index < _currentIndex) {
                                  progress = 1.0;
                                } else if (index == _currentIndex) {
                                  progress = _animController.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 3.0,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 6),
                        const Icon(Icons.favorite, color: DyKalTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Cerita Kita',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
