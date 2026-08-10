import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme.dart';
import '../../../models/chat_message.dart';
import '../../../services/sticker_store.dart';
import '../../../widgets/fullscreen_media_viewer.dart';
import '../../../services/auth_service.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onSwipeReply;
  final VoidCallback onLove;
  final Function(String) onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDownload;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onSwipeReply,
    required this.onLove,
    required this.onEdit,
    required this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
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
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: DyKalTheme.primary),
                      ),
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
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: message.type == MessageType.image
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? DyKalTheme.primary : DyKalTheme.cardOf(context),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
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
                    if (message.type == MessageType.voice && message.voiceUrl != null)
                      _VoicePlayer(
                        url: message.voiceUrl!,
                        duration: message.voiceDuration ?? 0,
                        accent: isMe ? Colors.white : DyKalTheme.primary,
                        trackColor: isMe ? Colors.white70 : DyKalTheme.textSecondaryOf(context),
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
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
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
            ],
          ),
        ),
      ),
    );
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

  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(color: Colors.black.withValues(alpha: 0.32)),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DyKalTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: DyKalTheme.borderSoftDark),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _act(Icons.reply_rounded, 'Balas', const Color(0xFF0A84FF), () {
                          Navigator.pop(ctx);
                          onSwipeReply();
                        }),
                        if (isMe && message.type == MessageType.text)
                          _act(Icons.edit_rounded, 'Edit', const Color(0xFF0A84FF), () {
                            Navigator.pop(ctx);
                            _editDialog(ctx);
                          }),
                        if (isMe)
                          _act(Icons.delete_rounded, 'Hapus', Colors.redAccent, () {
                            Navigator.pop(ctx);
                            onDelete();
                          }),
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

  Widget _act(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
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
              CachedNetworkImage(imageUrl: message.imageUrl!, width: 120, height: 120, fit: BoxFit.contain),
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
                    final p = await StickerStore.addFromUrl(message.imageUrl!);
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
  const _VoicePlayer({required this.url, required this.duration, required this.accent, required this.trackColor});

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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
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
              try {
                await _player.setUrl(widget.url);
                await _player.play();
              } catch (_) {}
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
                  final curSec = pos.inSeconds;
                  return Text(
                    '${curSec ~/ 60}:${(curSec % 60).toString().padLeft(2, '0')} / ${widget.duration}s',
                    style: TextStyle(fontSize: 11, color: widget.trackColor),
                  );
                },
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, s) {
                    final pos = s.data?.inMilliseconds ?? 0;
                    final total = (widget.duration > 0 ? widget.duration * 1000 : 1);
                    return LinearProgressIndicator(
                      value: (pos / total).clamp(0.0, 1.0),
                      backgroundColor: widget.trackColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
                      minHeight: 3,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
