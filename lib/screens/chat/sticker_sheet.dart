import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/sticker_store.dart';

/// Panel stiker: tab Emoji + tab Stiker lokal + tombol Buat Stiker.
class StickerSheet extends StatefulWidget {
  final List<String> emojis;
  final ValueChanged<String> onEmoji;
  final ValueChanged<File> onSendLocal;
  final VoidCallback onMake;
  const StickerSheet({super.key, required this.emojis, required this.onEmoji, required this.onSendLocal, required this.onMake});

  @override
  State<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<StickerSheet> {
  List<File> _locals = [];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await StickerStore.list();
    if (mounted) setState(() => _locals = l);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 340,
        child: Column(children: [
          // Tabs
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: DyKalTheme.cardOf(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Row(children: [
              _tabBtn('Emoji', 0, Icons.emoji_emotions_outlined),
              _tabBtn('Stiker', 1, Icons.image_outlined),
            ]),
          ),
          Expanded(child: _tab == 0 ? _emojiGrid() : _localGrid()),
          // Buat stiker
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: widget.onMake, icon: const Icon(Icons.add_reaction_outlined, size: 18), label: const Text('Buat Stiker (dari Galeri)'))),
          ),
        ]),
      ),
    );
  }

  Widget _tabBtn(String label, int idx, IconData icon) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _tab = idx), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: active ? Colors.white : DyKalTheme.textGrey), const SizedBox(width: 6), Text(label, style: TextStyle(color: active ? Colors.white : DyKalTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 12))]))));
  }

  Widget _emojiGrid() => GridView.count(crossAxisCount: 6, padding: const EdgeInsets.symmetric(horizontal: 8), children: widget.emojis.map((e) => GestureDetector(onTap: () => widget.onEmoji(e), child: Center(child: Text(e, style: const TextStyle(fontSize: 28))))).toList());

  Widget _localGrid() {
    if (_locals.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sentiment_satisfied, size: 40, color: DyKalTheme.textGrey.withOpacity(0.4)),
        const SizedBox(height: 8),
        Text('Belum ada stiker', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 13)),
        Text('Buat stiker pertama kamu', style: TextStyle(color: DyKalTheme.textGrey.withOpacity(0.6), fontSize: 11)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
      itemCount: _locals.length,
      itemBuilder: (_, i) => GestureDetector(onTap: () => widget.onSendLocal(_locals[i]), child: Padding(padding: const EdgeInsets.all(4), child: Image.file(_locals[i], fit: BoxFit.contain))),
    );
  }
}
