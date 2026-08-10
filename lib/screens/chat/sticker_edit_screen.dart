import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
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
  bool _saving = false;
  File? _cropped;
  final GlobalKey _repaintKey = GlobalKey();

  // Teks & latar
  String _text = '';
  Offset _textOffset = const Offset(40, 40);
  Color _bgColor = Colors.transparent;

  Future<void> _crop() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: (_cropped ?? widget.image).path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Stiker',
          toolbarColor: const Color(0xFF101215),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.rectangle,
        ),
        IOSUiSettings(title: 'Crop Stiker'),
      ],
    );
    if (cropped != null) setState(() => _cropped = File(cropped.path));
  }

  Future<void> _addText() async {
    final c = TextEditingController(text: _text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2029),
        title: const Text('Teks Stiker', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ketik teks...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) setState(() => _text = text);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      File finalFile = _cropped ?? widget.image;
      // Jika ada teks, render gabungan (image + teks) via RepaintBoundary
      if (_text.isNotEmpty) {
        final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 3);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            final tmp = await getTemporaryDirectory();
            final cap = '${tmp.path}/stk_cap_${DateTime.now().millisecondsSinceEpoch}.png';
            await File(cap).writeAsBytes(bytes.buffer.asUint8List());
            finalFile = File(cap);
          }
        }
      }
      final tmp = await getTemporaryDirectory();
      final out = '${tmp.path}/stk_${DateTime.now().millisecondsSinceEpoch}.png';
      final target = _size.round();
      await FlutterImageCompress.compressAndGetFile(
        finalFile.absolute.path,
        out,
        minWidth: target,
        minHeight: target,
        quality: 92,
        format: CompressFormat.png,
      );
      final dest = await StickerStore.add(File(out));
      if (mounted) {
        Navigator.pop(context, dest);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dest == null ? 'Gagal menyimpan stiker' : 'Stiker tersimpan')));
      }
    } catch (e) {
      final dest = await StickerStore.add(_cropped ?? widget.image);
      if (mounted) Navigator.pop(context, dest);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _cropped ?? widget.image;
    return Scaffold(
      backgroundColor: const Color(0xFF101215),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101215),
        foregroundColor: Colors.white,
        title: const Text('Buat Stiker'),
        actions: [
          IconButton(
            tooltip: 'Crop',
            onPressed: _saving ? null : _crop,
            icon: const Icon(Icons.crop, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Teks',
            onPressed: _saving ? null : _addText,
            icon: const Icon(Icons.text_fields, color: Colors.white),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan', style: TextStyle(color: DyKalTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Toolbar latar belakang
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Text('Latar:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 10),
                  for (final c in [
                    Colors.transparent,
                    Colors.white,
                    Colors.black,
                    DyKalTheme.primary,
                    DyKalTheme.secondary,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => _bgColor = c),
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c == Colors.transparent ? Colors.white12 : c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _bgColor == c ? DyKalTheme.primary : Colors.white24,
                            width: _bgColor == c ? 2.5 : 1,
                          ),
                        ),
                        child: c == Colors.transparent
                            ? const Icon(Icons.block, color: Colors.white38, size: 16)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Container(
                    color: _bgColor,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
                          child: InteractiveViewer(
                            maxScale: 4,
                            child: Image.file(show, fit: BoxFit.contain),
                          ),
                        ),
                        if (_text.isNotEmpty)
                          Positioned(
                            left: _textOffset.dx,
                            top: _textOffset.dy,
                            child: GestureDetector(
                              onPanUpdate: (d) => setState(() => _textOffset += d.delta),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.photo_size_select_large, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text('Ukuran: ${_size.round()} px', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                Slider(value: _size, min: 200, max: 512, divisions: 8, activeColor: DyKalTheme.primary, onChanged: (v) => setState(() => _size = v)),
                const SizedBox(height: 4),
                Text(
                  'Geser teks untuk memindah. Stiker disimpan lokal di Android/media/com.dykal.app/Dykal/Stiker/',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
