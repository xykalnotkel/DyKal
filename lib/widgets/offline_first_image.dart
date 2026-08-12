import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/e2e_service.dart';
import '../services/media_cache.dart';

/// Gambar OFFLINE-FIRST ala WA: cek file lokal (MediaCache) duluan —
/// media yang pernah terunduh tetap tampil walau internet mati. Kalau belum
/// ada di lokal, fallback ke CDN (CachedNetworkImage punya disk cache sendiri).
///
/// BATCH L: diekstrak dari message_bubble.dart agar bisa dipakai ulang oleh
/// album, story viewer, fullscreen viewer, dan avatar cerita — satu jalur
/// render untuk semua (termasuk dekripsi E2E).
class OfflineFirstImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  const OfflineFirstImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  /// Resolusi tampilan:
  /// 1. File lokal (MediaCache) — jalur offline.
  /// 2. URL E2E (/dykal/e2e/): unduh ciphertext -> DEKRIPSI -> simpan lokal.
  /// 3. Bukan E2E & belum lokal -> null -> CDN biasa.
  static Future<String?> _resolve(String url) async {
    final hit = await MediaCache.get(url);
    if (hit != null) return hit;
    if (E2EService.isEncryptedUrl(url)) {
      final plain = await E2EService.downloadDecrypted(url, ext: 'webp');
      if (plain != null) await MediaCache.put(url, plain);
      return plain;
    }
    return null;
  }

  @override
  State<OfflineFirstImage> createState() => _OfflineFirstImageState();
}

class _OfflineFirstImageState extends State<OfflineFirstImage> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _future = OfflineFirstImage._resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant OfflineFirstImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = OfflineFirstImage._resolve(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (_, snap) {
        final path = snap.data;
        if (path != null) {
          return Image.file(
            File(path),
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, __, ___) => _cdn(),
          );
        }
        // URL E2E yang gagal dekripsi JANGAN dilempar ke CDN (isinya
        // ciphertext — CDN akan error). Tampilkan placeholder terkunci.
        if (E2EService.isEncryptedUrl(widget.url)) return _locked();
        return _cdn();
      },
    );
  }

  Widget _locked() {
    return Container(
      width: widget.width,
      height: widget.height ?? 120,
      color: const Color(0x22000000),
      child: const Center(child: Icon(Icons.lock_outline, color: Colors.white54)),
    );
  }

  Widget _cdn() {
    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder != null ? (_, __) => widget.placeholder! : null,
      errorWidget: (_, __, ___) => Container(
        width: widget.width,
        height: widget.height ?? 120,
        color: const Color(0x22000000),
        child: const Icon(Icons.wifi_off_outlined, color: Colors.white54),
      ),
    );
  }
}
