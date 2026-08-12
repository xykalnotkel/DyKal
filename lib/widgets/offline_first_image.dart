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
class OfflineFirstImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolve(url),
      builder: (_, snap) {
        final path = snap.data;
        if (path != null) {
          return Image.file(
            File(path),
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => _cdn(),
          );
        }
        // URL E2E yang gagal dekripsi JANGAN dilempar ke CDN (isinya
        // ciphertext — CDN akan error). Tampilkan placeholder terkunci.
        if (E2EService.isEncryptedUrl(url)) return _locked();
        return _cdn();
      },
    );
  }

  Widget _locked() {
    return Container(
      width: width,
      height: height ?? 120,
      color: const Color(0x22000000),
      child: const Center(child: Icon(Icons.lock_outline, color: Colors.white54)),
    );
  }

  Widget _cdn() {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder != null ? (_, __) => placeholder! : null,
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height ?? 120,
        color: const Color(0x22000000),
        child: const Icon(Icons.wifi_off_outlined, color: Colors.white54),
      ),
    );
  }
}
