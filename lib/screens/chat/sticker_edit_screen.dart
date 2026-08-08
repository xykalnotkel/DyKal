import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../services/sticker_store.dart';

class StickerEditScreen extends StatefulWidget {
  final File image;
  const StickerEditScreen({super.key, required this.image});

  @override
  State<StickerEditScreen> createState() => _StickerEditScreenState();
}

class _StickerEditScreenState extends State<StickerEditScreen> {
  double _size = 384; // px target
  double _scale = 1.0; // preview zoom
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tmp = await getTemporaryDirectory();
      final out = '${tmp.path}/stk_${DateTime.now().millisecondsSinceEpoch}.png';
      final target = _size.round();
      await FlutterImageCompress.compressAndGetFile(
        widget.image.absolute.path,
        out,
        minWidth: target,
        minHeight: target,
        quality: 92,
        format: CompressFormat.png,
      );
      final dest = await StickerStore.add(File(out));
      if (mounted) {
        Navigator.pop(context, dest);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dest == null ? 'Gagal menyimpan stiker' : 'Stiker tersimpan ✅')));
      }
    } catch (e) {
      // fallback: simpan apa adanya
      final dest = await StickerStore.add(widget.image);
      if (mounted) Navigator.pop(context, dest);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101215),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101215),
        foregroundColor: Colors.white,
        title: const Text('Buat Stiker'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan', style: TextStyle(color: DyKalTheme.primary, fontWeight: FontWeight.w700)))],
      ),
      body: SafeArea(child: Column(children: [
        Expanded(child: Center(child: InteractiveViewer(child: Image.file(widget.image, fit: BoxFit.contain)))),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Icon(Icons.photo_size_select_large, color: Colors.white70, size: 18), const SizedBox(width: 8), Text('Ukuran: ${_size.round()} px', style: const TextStyle(color: Colors.white70, fontSize: 13))]),
            Slider(value: _size, min: 200, max: 512, divisions: 8, activeColor: DyKalTheme.primary, onChanged: (v) => setState(() => _size = v)),
            const SizedBox(height: 4),
            Text('Stiker disimpan lokal di Android/media/com.dykal.app/Dykal/Stiker/', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10), textAlign: TextAlign.center),
          ]),
        ),
      ])),
    );
  }
}
