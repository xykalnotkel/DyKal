import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/sticker_store.dart';

class StickerSheet extends StatefulWidget {
  final ValueChanged<String> onEmoji;
  final ValueChanged<File> onSendLocal;
  final VoidCallback onMake;

  const StickerSheet({
    super.key,
    required this.onEmoji,
    required this.onSendLocal,
    required this.onMake,
  });

  @override
  State<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<StickerSheet> {
  List<File> _locals = [];
  int _mainTab = 0; // 0: Emoji Penuh, 1: Stiker Koleksi
  int _emojiCategoryIdx = 0;

  static const Map<String, List<String>> _emojiCategories = {
    'Romantis': [
      '❤️', '💖', '💕', '💞', '💓', '💗', '💘', '💝', '💟', '💌', '💍', '💎',
      '🥰', '😍', '😘', '😗', '😙', '😚', '😻', '💋', '👄', '👩‍❤️‍👨', '👩‍❤️‍👩', '👨‍❤️‍👨',
      '💑', '👩‍❤️‍💋‍👨', '🌹', '🥀', '🌺', '🌸', '🌼', '🌻', '💐', '🕊️'
    ],
    'Ekspresi': [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥹', '😊', '😇', '🙂',
      '🙃', '😉', '😌', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫',
      '🤔', '🫡', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '😮‍💨',
      '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧',
      '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '🥸', '😎', '🤓', '🧐', '😕',
      '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥',
      '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡'
    ],
    'Gestur': [
      '👋', '🤚', '🖐️', '✋', '🖖', '🫱', '🫲', '🫳', '🫴', '👌', '🤌', '🤏',
      '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️',
      '🫵', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '🫶', '👐', '🤲',
      '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻'
    ],
    'Perayaan': [
      '🎉', '🎊', '🎈', '🎂', '🍰', '🧁', '🎁', '🎀', '🪄', '🪅', '🎆', '🎇',
      '✨', '🌟', '⭐', '💫', '💥', '🔥', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️',
      '👑', '🕯️', '🧸', '🪆', '🎄', '🎃', '🧧', '🏮', '🥂', '🍾', '🍻', '🍷'
    ],
    'Makanan': [
      '☕', '🧋', '🍵', '🥛', '🧃', '🥤', '🍦', '🍧', '🍨', '🍩', '🍪', '🍫',
      '🍬', '🍭', '🍮', '🍯', '🍓', '🍒', '🍎', '🍉', '🍇', '🍑', '🥭', '🍍',
      '🍕', '🍔', '🍟', '🌭', '🥪', '🌮', '🌯', '🍜', '🍝', '🍣', '🍱', '🍙'
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await StickerStore.list();
    if (mounted) setState(() => _locals = l);
  }

  void _showStickerOptions(File file, Uint8List? bytes) {
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
              if (bytes != null)
                Image.memory(bytes, width: 120, height: 120, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const Text('Stiker Koleksi DyKal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const Text('Format: WebP Terenkripsi AES-256-GCM', style: TextStyle(color: DyKalTheme.textMutedDark, fontSize: 12)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (await file.exists()) {
                          await file.delete();
                          _load();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: DyKalTheme.primary),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final tmp = await StickerStore.tempDecryptedFile(file);
                        if (tmp != null) widget.onSendLocal(tmp);
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kirim Stiker'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 380,
        child: Column(
          children: [
            // Top Main Tabs
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: DyKalTheme.cardOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DyKalTheme.borderOf(context)),
              ),
              child: Row(
                children: [
                  _mainTabBtn('Emoji Lengkap', 0, Icons.emoji_emotions_outlined),
                  _mainTabBtn('Koleksi Stiker', 1, Icons.auto_awesome_motion_outlined),
                ],
              ),
            ),

            // Sub Categories (jika mode emoji aktif)
            if (_mainTab == 0) _buildEmojiCategorySelector(),

            // Content Area
            Expanded(child: _mainTab == 0 ? _buildEmojiGrid() : _buildStickerGrid()),

            // Bottom Add Sticker Button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onMake,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Buat Stiker Baru (dari Galeri)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainTabBtn(String label, int idx, IconData icon) {
    final active = _mainTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mainTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? DyKalTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : DyKalTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : DyKalTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiCategorySelector() {
    final keys = _emojiCategories.keys.toList();
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final active = _emojiCategoryIdx == i;
          return GestureDetector(
            onTap: () => setState(() => _emojiCategoryIdx = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? DyKalTheme.primary.withValues(alpha: 0.15)
                    : DyKalTheme.cardOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? DyKalTheme.primary : DyKalTheme.borderOf(context),
                ),
              ),
              child: Center(
                child: Text(
                  keys[i],
                  style: TextStyle(
                    color: active ? DyKalTheme.primary : DyKalTheme.textSecondaryOf(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final keys = _emojiCategories.keys.toList();
    final list = _emojiCategories[keys[_emojiCategoryIdx]] ?? [];
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final emoji = list[i];
        return GestureDetector(
          onTap: () => widget.onEmoji(emoji),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid() {
    if (_locals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_motion_outlined, size: 40, color: DyKalTheme.textSecondaryOf(context)),
            const SizedBox(height: 8),
            Text('Belum ada stiker di koleksi', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 13)),
            Text('Buat stiker pertama kamu dengan tombol di bawah', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 11)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _locals.length,
      itemBuilder: (_, i) => FutureBuilder<Uint8List?>(
        future: StickerStore.readDecrypted(_locals[i]),
        builder: (_, snap) {
          final bytes = snap.data;
          return GestureDetector(
            onTap: () async {
              final tmp = await StickerStore.tempDecryptedFile(_locals[i]);
              if (tmp != null) widget.onSendLocal(tmp);
            },
            onLongPress: () => _showStickerOptions(_locals[i], bytes),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: (bytes != null)
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: DyKalTheme.primary),
                    ),
            ),
          );
        },
      ),
    );
  }
}
