import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme.dart';
import '../../../models/chat_message.dart';
import '../../../services/bubble_style.dart';
import '../../../services/e2e_service.dart';
import '../../../services/media_cache.dart';
import '../../../services/sticker_store.dart';
import '../../../services/voice_cache.dart';
import '../../../widgets/fullscreen_media_viewer.dart';
import '../../../services/auth_service.dart';

/// Gambar OFFLINE-FIRST ala WA: cek file lokal (MediaCache) duluan —
/// media yang pernah terunduh tetap tampil walau internet mati. Kalau belum
/// ada di lokal, fallback ke CDN (CachedNetworkImage punya disk cache sendiri).
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


class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onSwipeReply;
  final VoidCallback onLove;
  final Function(String) onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeleteForMe;
  final void Function(String) onReact;
  final VoidCallback? onDownload;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onSwipeReply,
    required this.onLove,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteForMe,
    required this.onReact,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    // Hapus untuk saya (per-user) juga dianggap terhapus bagi user tsb.
    final deletedForMe = message.deletedFor.contains(AuthService().myId);
    if (message.isDeleted || deletedForMe) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? DyKalTheme.surfaceDark
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14, color: DyKalTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                'Pesan ini telah dihapus',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: DyKalTheme.textSecondaryOf(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pesan sistem (log panggilan, dsb)
    if (message.type == MessageType.system) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: DyKalTheme.textSecondaryOf(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 12,
              color: DyKalTheme.textSecondaryOf(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Stiker Interaktif
    if (message.type == MessageType.sticker) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            if (message.imageUrl != null) _showStickerSheet(context);
          },
          onLongPress: () => _showOptions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.imageUrl != null)
                  OfflineFirstImage(
                    url: message.imageUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: DyKalTheme.primary),
                      ),
                    ),
                  )
                else if (message.status == MessageStatus.sending)
                  // Sedang upload stiker (ikon jam, tanpa spinner memblokir)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withValues(alpha: 0.15) : DyKalTheme.borderOf(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.schedule, color: DyKalTheme.primary, size: 28),
                    ),
                  )
                else
                  Text(message.text, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatTime(message.createdAt), style: TextStyle(fontSize: 10, color: DyKalTheme.textSecondaryOf(context))),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _statusIcon(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // View Once Bubble ala WhatsApp
    if (message.isViewOnce || message.type == MessageType.viewOnce) {
      final isOpened = message.viewOnceOpened;
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            if (isOpened) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Foto sekali lihat ini sudah dibuka')),
              );
              return;
            }
            if (!isMe && message.imageUrl != null) {
              FullscreenMediaViewer.open(
                context,
                url: message.imageUrl!,
                fromName: 'Foto Sekali Lihat',
                onDelete: () {
                  _markViewOnceOpened();
                },
              );
              _markViewOnceOpened();
            } else if (isMe) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pesan sekali lihat yang kamu kirim')),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? (isOpened ? Colors.grey.shade700 : DyKalTheme.primary)
                  : (isOpened ? DyKalTheme.surfaceDark : DyKalTheme.cardOf(context)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOpened
                    ? Colors.transparent
                    : (isMe ? Colors.transparent : DyKalTheme.borderOf(context)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOpened
                        ? Colors.white24
                        : (isMe ? Colors.white24 : DyKalTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Icon(
                    isOpened ? Icons.check_circle_outline_rounded : Icons.looks_one_rounded,
                    color: isMe
                        ? Colors.white
                        : (isOpened ? DyKalTheme.textSecondaryOf(context) : DyKalTheme.primary),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOpened ? 'Foto • Dibuka' : 'Foto Sekali Lihat',
                  style: TextStyle(
                    color: isMe
                        ? Colors.white
                        : (isOpened ? DyKalTheme.textSecondaryOf(context) : DyKalTheme.textPrimaryOf(context)),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontStyle: isOpened ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _statusIcon(),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipeReply();
        return false;
      },
      background: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.reply, color: DyKalTheme.primary),
        ),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showOptions(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: message.type == MessageType.image
                    ? const EdgeInsets.all(3)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? DyKalTheme.primary : DyKalTheme.cardOf(context),
                  // Radius mengikuti gaya pilihan pengguna (Bulat/Kotak/Ekor)
                  borderRadius: BubbleStyle.instance.radius(isMe),
                  border: isMe ? null : Border.all(color: DyKalTheme.borderOf(context)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToText != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.2)
                              : DyKalTheme.primary.withValues(alpha: 0.08),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white : DyKalTheme.primary,
                              width: 2.5,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToName ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : DyKalTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              message.replyToText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (message.type == MessageType.voice && message.voiceUrl == null)
                      // Voice note sedang di-upload: tampil dengan ikon jam
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_none,
                              size: 20,
                              color: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Voice note',
                              style: TextStyle(
                                fontSize: 13,
                                color: isMe ? Colors.white : DyKalTheme.textPrimaryOf(context),
                              ),
                            ),
                            if (message.status == MessageStatus.sending) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.schedule, size: 14, color: DyKalTheme.primary),
                            ],
                          ],
                        ),
                      ),
                    if (message.type == MessageType.voice && message.voiceUrl != null)
                      _VoicePlayer(
                        url: message.voiceUrl!,
                        duration: message.voiceDuration ?? 0,
                        wave: message.voiceWave,
                        accent: isMe ? Colors.white : DyKalTheme.primary,
                        trackColor: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                      ),
                    if (message.imageUrl == null &&
                        message.status == MessageStatus.sending &&
                        (message.type == MessageType.image))
                      // Foto sedang di-upload: placeholder ikon jam
                      Container(
                        width: 150,
                        height: 200,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white.withValues(alpha: 0.15) : DyKalTheme.borderOf(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(Icons.schedule, size: 30, color: DyKalTheme.primary),
                        ),
                      ),
                    if (message.imageUrl != null)
                      GestureDetector(
                        onTap: () => FullscreenMediaViewer.open(
                          context,
                          url: message.imageUrl!,
                          fromName: isMe ? 'Kamu' : (message.replyToName ?? 'Pasangan'),
                          createdAt: (message.createdAt as dynamic)?.toDate(),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: OfflineFirstImage(
                            url: message.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              height: 180,
                              color: DyKalTheme.borderOf(context),
                            ),
                          ),
                        ),
                      ),
                    if (message.text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: message.imageUrl != null ? 8 : 0),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : DyKalTheme.textPrimaryOf(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (BubbleStyle.instance.metaInside)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isEdited)
                            Text(
                              'diedit • ',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                              ),
                            ),
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            _statusIcon(),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              if (message.isLoved)
                Positioned(
                  bottom: -6,
                  right: isMe ? null : -6,
                  left: isMe ? -6 : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: DyKalTheme.surfaceDark,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.favorite, color: DyKalTheme.primary, size: 14),
                  ),
                ),
              // Reaksi emoji (badge di pojok bubble)
              if (message.reaction != null && message.reaction!.isNotEmpty)
                Positioned(
                  bottom: -12,
                  right: isMe ? -4 : null,
                  left: isMe ? null : -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: DyKalTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DyKalTheme.borderSoftDark),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(message.reaction!, style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
          // META DI LUAR BUBBLE (mode iOS) — status terkirim + waktu di bawah
          // bubble. Dipilih pengguna via Settings > Tampilan.
          if (!BubbleStyle.instance.metaInside)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited)
                    Text(
                      'diedit • ',
                      style: TextStyle(fontSize: 10, color: DyKalTheme.textSecondaryOf(context)),
                    ),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 10, color: DyKalTheme.textSecondaryOf(context)),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _outsideStatusIcon(),
                  ],
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ikon status versi luar-bubble (warna tema — bukan putih, biar terbaca
  /// di atas wallpaper terang).
  Widget _outsideStatusIcon() {
    final base = DyKalTheme.textSecondaryOf(context);
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 12, color: base);
      case MessageStatus.sent:
        return Icon(Icons.check, size: 12, color: base);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 12, color: base);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: DyKalTheme.online);
    }
  }

  void _markViewOnceOpened() {
    final cid = AuthService().coupleId;
    if (cid != null && cid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('chats/$cid/messages')
          .doc(message.id)
          .update({'viewOnceOpened': true});
    }
  }

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const Icon(Icons.schedule, size: 12, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: DyKalTheme.online);
    }
  }

  String _formatTime(dynamic ts) {
    try {
      final dt = ts.toDate();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Menu opsi saat bubble ditahan: background blur + menu di bawah bubble.
  /// Isi: reaksi emoji, balas, edit (pesan sendiri), favorit, hapus untuk saya,
  /// hapus untuk semua.
  void _showOptions(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final bubblePos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final bubbleSize = box?.size ?? Size.zero;
    final overlaySize = MediaQuery.of(context).size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Opsi pesan',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, __) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            // Background blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            // Menu di bawah bubble
            Positioned(
              left: 12,
              right: 12,
              top: (bubblePos.dy + bubbleSize.height + 10).clamp(8.0, overlaySize.height - 340),
              child: _menuPanel(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuPanel(BuildContext ctx) {
    const reactions = ['❤️', '😂', '😮', '😢', '🙏', '🎉'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DyKalTheme.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DyKalTheme.borderSoftDark),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reaksi emoji
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: reactions.map((e) {
              final active = message.reaction == e;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onReact(active ? '' : e); // ketuk lagi = hapus reaksi
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active ? DyKalTheme.primary.withValues(alpha: 0.25) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 20, color: DyKalTheme.borderSoftDark),
          _act(Icons.reply_rounded, 'Balas', const Color(0xFF0A84FF), () {
            Navigator.pop(ctx);
            onSwipeReply();
          }),
          if (isMe && message.type == MessageType.text)
            _act(Icons.edit_rounded, 'Edit Pesan', const Color(0xFF0A84FF), () {
              Navigator.pop(ctx);
              _editDialog(ctx);
            }),
          _act(message.isLoved ? Icons.favorite : Icons.favorite_border,
              message.isLoved ? 'Hapus Favorit' : 'Favorit', DyKalTheme.primary, () {
            Navigator.pop(ctx);
            onLove();
          }),
          _act(Icons.delete_outline, 'Hapus untuk Saya', Colors.orangeAccent, () {
            Navigator.pop(ctx);
            onDeleteForMe();
          }),
          _act(Icons.delete_forever_rounded, 'Hapus untuk Semua', Colors.redAccent, () {
            Navigator.pop(ctx);
            onDelete();
          }),
        ],
      ),
    );
  }

  Widget _act(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showStickerSheet(BuildContext context) {
    if (message.imageUrl == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OfflineFirstImage(url: message.imageUrl!, width: 120, height: 120, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const Text('Stiker Kustom DyKal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const Text('Format: WebP Terenkripsi (AES-256-GCM)', style: TextStyle(color: DyKalTheme.textMutedDark, fontSize: 12)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: DyKalTheme.primary),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    String? p;
                    if (E2EService.isEncryptedUrl(message.imageUrl)) {
                      // Stiker E2E: unduh cipher -> dekripsi -> impor file lokal
                      final plain = await E2EService.downloadDecrypted(message.imageUrl!, ext: 'webp');
                      if (plain != null) p = await StickerStore.add(File(plain));
                    } else {
                      p = await StickerStore.addFromUrl(message.imageUrl!);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(p == null ? 'Gagal menyimpan stiker' : 'Stiker ditambahkan ke Koleksi Favorit')),
                      );
                    }
                  },
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Simpan ke Stiker Favorit'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup', style: TextStyle(color: DyKalTheme.textMutedDark)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editDialog(BuildContext context) {
    final c = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Pesan'),
        content: TextField(controller: c, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onEdit(c.text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  final String url;
  final int duration;
  final Color accent;
  final Color trackColor;
  final List<int>? wave; // sampel gelombang asli (0-100) dari perekam
  const _VoicePlayer({required this.url, required this.duration, required this.accent, required this.trackColor, this.wave});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late final AudioPlayer _player;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((s) {
      final p = s.playing;
      final proc = s.processingState;
      if (proc == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      if (mounted) setState(() => _playing = p && proc != ProcessingState.completed);
    });
  }

  /// Putar: pakai file lokal (offline) jika pernah disimpan. URL E2E
  /// (/dykal/e2e/) diunduh + didekripsi dulu ke file lokal (audio E2E tidak
  /// bisa di-streaming langsung — isinya ciphertext).
  Future<void> _play() async {
    try {
      String? path = await VoiceCache.get(widget.url);
      if (path != null && !await File(path).exists()) path = null;
      if (path == null && E2EService.isEncryptedUrl(widget.url)) {
        path = await E2EService.downloadDecrypted(widget.url, ext: 'm4a');
        if (path != null) await VoiceCache.put(widget.url, path);
      }
      if (path != null) {
        await _player.setFilePath(path);
      } else {
        await _player.setUrl(widget.url);
      }
      await _player.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  /// GELOMBANG ASLI ala WA (permintaan owner): bar dibangun dari sampel
  /// amplitudo yang ditangkap saat merekam — bukan garis lurus statis.
  /// Bagian yang sudah diputar diwarnai aksen, sisanya warna track.
  Widget _waveform(double progress) {
    // Maksimum 30 bar: downsample sampel mentah (maks 90) dengan rata-rata.
    const barCount = 30;
    final src = (widget.wave != null && widget.wave!.isNotEmpty)
        ? widget.wave!
        : List.generate(barCount, (i) => 25 + ((i * 41) % 50)); // fallback sintetis utk VN lama
    final samples = List<int>.generate(barCount, (i) {
      final start = (i * src.length / barCount).floor();
      var end = ((i + 1) * src.length / barCount).floor();
      if (end <= start) end = start + 1;
      var sum = 0;
      var n = 0;
      for (var j = start; j < end && j < src.length; j++) {
        sum += src[j];
        n++;
      }
      return n == 0 ? 20 : (sum / n).round();
    });
    final playedBars = (progress * barCount).clamp(0, barCount).floor();
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < barCount; i++)
            Container(
              width: 3,
              height: 4 + (samples[i].clamp(8, 100) / 100) * 22,
              decoration: BoxDecoration(
                color: i < playedBars ? widget.accent : widget.trackColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            if (_playing) {
              await _player.pause();
            } else {
              await _play();
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: widget.accent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (_, s) {
                  final pos = s.data ?? Duration.zero;
                  final total = widget.duration;
                  return _waveform(total > 0 ? (pos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0) : 0.0);
                },
              ),
              const SizedBox(height: 2),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (_, s) {
                  final pos = s.data ?? Duration.zero;
                  // DURASI REAL: posisi jalan / total mm:ss
                  return Text(
                    '${_fmt(pos.inSeconds)} / ${_fmt(widget.duration)}',
                    style: TextStyle(fontSize: 11, color: widget.trackColor),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
