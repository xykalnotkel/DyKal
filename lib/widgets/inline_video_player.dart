import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/e2e_service.dart';
import '../services/media_cache.dart';

/// Video inline sederhana (Batch L): satu jalur putar untuk 3 sumber —
///  1. path lokal langsung
///  2. URL E2E (/dykal/e2e/) -> unduh ciphertext -> DEKRIPSI -> file lokal
///  3. URL CDN biasa -> VideoPlayerController.network (cache bawaan ExoPlayer)
/// Dipakai oleh fullscreen viewer (video) & pratinjau kirim video.
class InlineVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final bool loop;

  const InlineVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = true,
    this.loop = true,
  });

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      var src = widget.url;
      // Offline-first + E2E (pola sama dengan OfflineFirstImage, ext mp4).
      final hit = await MediaCache.get(src);
      if (hit != null) {
        src = hit;
      } else if (E2EService.isEncryptedUrl(src)) {
        final plain = await E2EService.downloadDecrypted(src, ext: 'mp4');
        if (plain == null) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        await MediaCache.put(src, plain);
        src = plain;
      }
      if (!mounted) return;

      final c = src.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(src))
          : VideoPlayerController.file(File(src));
      await c.initialize();
      await c.setLooping(widget.loop);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => _c = c);
      if (widget.autoPlay) await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
      );
    }
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ),
        ],
      ),
    );
  }
}
