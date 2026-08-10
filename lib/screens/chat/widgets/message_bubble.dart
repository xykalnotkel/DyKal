import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../../../config/theme.dart';
import '../../../models/chat_message.dart';
import '../../../services/sticker_store.dart';

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
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.block, size: 14, color: Colors.grey),
            SizedBox(width: 6),
            Text("Pesan ini telah dihapus", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
          ]),
        ),
      );
    }

    // Pesan sistem: log panggilan / log pesan dihapus (tengah, tanpa bubble)
    if (message.type == MessageType.system) {
      return Align(
        alignment: Alignment.center,
        child: Container(margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: DyKalTheme.textGrey.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(message.text, style: TextStyle(fontSize: 11, color: DyKalTheme.textGrey, fontWeight: FontWeight.w500))),
      );
    }

    // Stiker (emoji besar atau gambar stiker tanpa bubble)
    if (message.type == MessageType.sticker) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () { if (!isMe && message.imageUrl != null) _addStikerMenu(context); },
          onLongPress: () => _showOptions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (message.imageUrl != null)
                CachedNetworkImage(imageUrl: message.imageUrl!, width: 140, height: 140, fit: BoxFit.contain, placeholder: (_, __) => const SizedBox(width: 140, height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B8A)))))
              else
                Text(message.text, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_formatTime(message.createdAt), style: TextStyle(fontSize: 10, color: DyKalTheme.textGrey)),
                if (isMe) ...[const SizedBox(width: 4), _statusIcon()],
              ]),
            ]),
          ),
        ),
      );
    }

    // View Once handling
    if (message.isViewOnce && !isMe && !message.viewOnceOpened) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            // Buka sekali, tandai opened
            showDialog(context: context, builder: (_) => Dialog(
              backgroundColor: Colors.black,
              child: Stack(children: [
                CachedNetworkImage(imageUrl: message.imageUrl!, fit: BoxFit.contain),
                Positioned(top: 12, right: 12, child: IconButton(onPressed: ()=> Navigator.pop(context), icon: Icon(Icons.close, color: Colors.white))),
              ]),
            ));
            // Update Firestore viewOnceOpened = true (nanti auto hapus)
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: DyKalTheme.dykalGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.visibility, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Foto sekali lihat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async { onSwipeReply(); return false; },
      background: Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.reply, color: DyKalTheme.primary))),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showOptions(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                margin: EdgeInsets.symmetric(vertical: 4),
                padding: message.type == MessageType.image ? const EdgeInsets.all(3) : const EdgeInsets.symmetric(horizontal: 12, vertical: 7), // FIX #9: bubble tipis (jangan terlalu tinggi)
                decoration: BoxDecoration(
                  color: isMe ? DyKalTheme.primary : DyKalTheme.cardOf(context),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe ? null : Border.all(color: DyKalTheme.borderOf(context)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (message.replyToText != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.2) : DyKalTheme.primary.withOpacity(0.08),
                        border: Border(left: BorderSide(color: isMe ? Colors.white : DyKalTheme.primary, width: 2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(message.replyToName ?? '', style: TextStyle(color: isMe ? Colors.white : DyKalTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(message.replyToText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : DyKalTheme.textGrey, fontSize: 12)),
                      ]),
                    ),
                  if (message.type == MessageType.voice && message.voiceUrl != null)
                    _VoicePlayer(
                      url: message.voiceUrl!,
                      duration: message.voiceDuration ?? 0,
                      accent: isMe ? Colors.white : DyKalTheme.primary,
                      trackColor: isMe ? Colors.white70 : DyKalTheme.textGrey,
                    ),
                  if (message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: message.imageUrl!, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 180, color: DyKalTheme.borderSoft)),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: message.imageUrl != null ? 8 : 0),
                      child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : DyKalTheme.textPrimaryOf(context), fontSize: 14)),
                    ),
                  SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (message.isEdited) Text("diedit • ", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : DyKalTheme.textGrey)),
                    Text(_formatTime(message.createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : DyKalTheme.textGrey)),
                    if (isMe) ...[
                      SizedBox(width: 4),
                      _statusIcon(),
                    ],
                  ]),
                ]),
              ),
              // Love icon
              if (message.isLoved)
                Positioned(
                  bottom: -6, right: isMe ? null : -6, left: isMe ? -6 : null,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: Icon(Icons.favorite, color: DyKalTheme.primary, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending: return Icon(Icons.schedule, size: 12, color: Colors.white70);
      case MessageStatus.sent: return Icon(Icons.check, size: 12, color: Colors.white70); // centang 1
      case MessageStatus.delivered: return Icon(Icons.done_all, size: 12, color: Colors.white70); // centang 2 abu
      case MessageStatus.read: return Icon(Icons.done_all, size: 12, color: Color(0xFF00D68F)); // centang 2 biru/hijau
    }
  }

  String _formatTime(dynamic ts) {
    try { return "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2,'0')}"; } catch (_) { return ""; }
  }

  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Stack(children: [
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7), child: Container(color: Colors.black.withOpacity(0.32)))),
          Center(child: _iOSMenu(ctx)),
        ]),
      ),
    );
  }

  Widget _iOSMenu(BuildContext ctx) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2E).withOpacity(0.96), borderRadius: BorderRadius.circular(22)),
        child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          if (message.imageUrl != null) _act(Icons.download_rounded, 'Simpan', DyKalTheme.primary, () { Navigator.pop(ctx); onDownload?.call(); }),
          _act(message.isLoved ? Icons.favorite : Icons.favorite_border, message.isLoved ? 'Hapus Love' : 'Love', DyKalTheme.primary, () { Navigator.pop(ctx); onLove(); }),
          _act(Icons.reply_rounded, 'Balas', const Color(0xFF0A84FF), () { Navigator.pop(ctx); onSwipeReply(); }),
          if (isMe && message.type == MessageType.text) _act(Icons.edit_rounded, 'Edit', const Color(0xFF0A84FF), () { Navigator.pop(ctx); _editDialog(ctx); }),
          if (isMe) _act(Icons.delete_rounded, 'Hapus Semua', Colors.redAccent, () { Navigator.pop(ctx); onDelete(); }),
          if (isMe) _act(Icons.delete_outline_rounded, 'Hapus Saya', Colors.redAccent, () { Navigator.pop(ctx); onDelete(); }),
        ]),
      ),
    );
  }

  Widget _act(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center)]),
      ),
    );
  }

  void _addStikerMenu(BuildContext context) {
    if (message.imageUrl == null) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      content: const Text('Tambahkan stiker ini ke koleksimu?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          final p = await StickerStore.addFromUrl(message.imageUrl!);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p == null ? 'Gagal menambah stiker' : 'Stiker ditambahkan ✅')));
        }, child: const Text('Tambah')),
      ],
    ));
  }

  void _editDialog(BuildContext context) {
    final c = TextEditingController(text: message.text);
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Edit Pesan'), content: TextField(controller: c, autofocus: true, maxLines: null), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () { Navigator.pop(context); onEdit(c.text); }, child: const Text('Simpan'))]));
  }
}

/// Player voice note sederhana (play/pause + progres + durasi)
class _VoicePlayer extends StatefulWidget {
  final String url;
  final int duration; // detik (estimasi)
  final Color accent;
  final Color trackColor;
  const _VoicePlayer({required this.url, required this.duration, required this.accent, required this.trackColor});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late final AudioPlayer _player;
  bool _loading = false;
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

  Future<void> _toggle() async {
    try {
      if (!_playing) {
        if (_player.audioSource == null) {
          setState(() => _loading = true);
          await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.url)));
          setState(() => _loading = false);
        }
        await _player.seek(Duration.zero);
        await _player.play();
      } else {
        await _player.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.duration > 0 ? Duration(seconds: widget.duration) : const Duration(seconds: 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: widget.accent.withOpacity(0.18), shape: BoxShape.circle),
            child: _loading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.accent))
                : Icon(_playing ? Icons.pause : Icons.play_arrow, color: widget.accent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (_, snap) {
            final pos = snap.data ?? Duration.zero;
            return Row(children: [
              Icon(Icons.graphic_eq, size: 16, color: widget.trackColor),
              const SizedBox(width: 6),
              Text(_fmt(pos), style: TextStyle(color: widget.trackColor, fontSize: 12)),
              const SizedBox(width: 4),
              Text('/ ${_fmt(dur)}', style: TextStyle(color: widget.trackColor, fontSize: 12)),
            ]);
          },
        ),
      ]),
    );
  }
}
