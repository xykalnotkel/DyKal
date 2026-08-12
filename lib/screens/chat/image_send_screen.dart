import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../widgets/inline_video_player.dart';

class ImageSendScreen extends StatefulWidget {
  final File image;
  const ImageSendScreen({super.key, required this.image});

  @override
  State<ImageSendScreen> createState() => _ImageSendScreenState();
}

class _DoodlePoint {
  final Offset point;
  final Paint paint;
  _DoodlePoint({required this.point, required this.paint});
}

class _ImageSendScreenState extends State<ImageSendScreen> {
  final _caption = TextEditingController();
  final GlobalKey _repaintKey = GlobalKey();

  late File _currentImage;
  bool _isViewOnce = false;
  bool _isHd = false;
  bool _isDrawingMode = false;

  /// BATCH L: layar ini juga dipakai saat galeri mengembalikan VIDEO —
  /// pratinjau pakai player, crop/doodle/doodle-kanvas dilewati.
  late final bool _isVideo = RegExp(r'\.(mp4|mov|3gp|mkv|webm)\$', caseSensitive: false).hasMatch(widget.image.path);
  bool _isSending = false;

  List<_DoodlePoint?> _points = [];
  Color _selectedColor = const Color(0xFFFF6B8A);
  double _strokeWidth = 4.0;
  String _overlayText = '';
  Offset _textOffset = const Offset(100, 100);

  final List<Color> _colorPalette = const [
    Color(0xFFFF6B8A), // Rose
    Color(0xFFFFFFFF), // White
    Color(0xFFFFC857), // Yellow
    Color(0xFF4ECDC4), // Cyan
    Color(0xFF7B6CF6), // Purple
    Color(0xFFFF2E93), // Magenta
    Color(0xFF00D68F), // Green
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _cropAndRotate() async {
    if (_isVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crop hanya untuk foto')),
      );
      return;
    }
    final cropped = await ImageCropper().cropImage(
      sourcePath: _currentImage.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Foto',
          toolbarColor: DyKalTheme.backgroundDark,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: DyKalTheme.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Edit Foto'),
      ],
    );

    if (cropped != null) {
      setState(() {
        _currentImage = File(cropped.path);
        _points.clear();
      });
    }
  }

  void _addTextOverlay() async {
    final c = TextEditingController(text: _overlayText);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DyKalTheme.surfaceDark,
        title: const Text('Tambahkan Teks', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ketik teks di sini...',
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

    if (text != null) {
      setState(() => _overlayText = text);
    }
  }

  Future<File> _renderFinalImage() async {
    if (_points.isEmpty && _overlayText.isEmpty) {
      return _currentImage;
    }

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: _isHd ? 2.5 : 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final tempDir = await getTemporaryDirectory();
          final finalFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
          await finalFile.writeAsBytes(byteData.buffer.asUint8List());
          return finalFile;
        }
      }
    } catch (_) {}

    return _currentImage;
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    // Video: LEWATI kanvas gambar (render PNG) — file diteruskan apa adanya.
    final finalFile = _isVideo ? widget.image : await _renderFinalImage();
    if (!mounted) return;

    // Upload TIDAK dilakukan di sini (agar tidak ada spinner blocking).
    // Kembalikan file lokal; chat_screen menulis pesan dgn ikon jam lalu
    // mengunggah di background (ala WhatsApp).
    Navigator.pop(context, {
      'localPath': finalFile.path,
      'caption': _caption.text.trim(),
      'viewOnce': _isViewOnce,
      'isHd': _isHd,
      'isVideo': _isVideo,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar
            _buildTopToolbar(),

            // Color Palette (jika mode drawing aktif)
            if (_isDrawingMode) _buildDrawingPalette(),

            // Main Editor Canvas
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      InteractiveViewer(
                        panEnabled: !_isDrawingMode,
                        scaleEnabled: !_isDrawingMode,
                        child: _isVideo
                            ? InlineVideoPlayer(url: _currentImage.path)
                            : Image.file(_currentImage, fit: BoxFit.contain),
                      ),
                      if (_points.isNotEmpty || _isDrawingMode)
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (details) {
                              if (!_isDrawingMode) return;
                              setState(() {
                                final paint = Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth;
                                _points.add(_DoodlePoint(point: details.localPosition, paint: paint));
                              });
                            },
                            onPanUpdate: (details) {
                              if (!_isDrawingMode) return;
                              setState(() {
                                final paint = Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth;
                                _points.add(_DoodlePoint(point: details.localPosition, paint: paint));
                              });
                            },
                            onPanEnd: (_) {
                              if (!_isDrawingMode) return;
                              setState(() => _points.add(null));
                            },
                            child: CustomPaint(
                              painter: _DoodlePainter(points: _points),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      if (_overlayText.isNotEmpty)
                        Positioned(
                          left: _textOffset.dx,
                          top: _textOffset.dy,
                          child: GestureDetector(
                            onPanUpdate: (d) => setState(() => _textOffset += d.delta),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _overlayText,
                                style: TextStyle(
                                  color: _selectedColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
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

            // Banner Notif View Once
            if (_isViewOnce)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: DyKalTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DyKalTheme.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.looks_one_rounded, color: DyKalTheme.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Foto Sekali Lihat diaktifkan: File otomatis dihapus setelah dibuka.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Caption & Action Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // HD Toggle
          GestureDetector(
            onTap: () => setState(() => _isHd = !_isHd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isHd ? DyKalTheme.primary : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isHd ? DyKalTheme.primary : Colors.white24),
              ),
              child: Text(
                'HD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Crop & Rotate
          IconButton(
            icon: const Icon(Icons.crop_rotate, color: Colors.white),
            onPressed: _cropAndRotate,
            tooltip: 'Crop / Putar',
          ),
          // Add Text
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.white),
            onPressed: _addTextOverlay,
            tooltip: 'Tambah Teks',
          ),
          // Drawing Pencil
          IconButton(
            icon: Icon(Icons.edit, color: _isDrawingMode ? DyKalTheme.primary : Colors.white),
            onPressed: _isVideo ? null : () => setState(() => _isDrawingMode = !_isDrawingMode),
            tooltip: 'Coret / Doodle',
          ),
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              onPressed: () => setState(() => _points.clear()),
              tooltip: 'Hapus Coretan',
            ),
        ],
      ),
    );
  }

  Widget _buildDrawingPalette() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ..._colorPalette.map(
            (c) => GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == c ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text('Ukuran: ', style: TextStyle(color: DyKalTheme.textMutedDark, fontSize: 11)),
          Slider(
            value: _strokeWidth,
            min: 2,
            max: 12,
            activeColor: _selectedColor,
            onChanged: (v) => setState(() => _strokeWidth = v),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: DyKalTheme.surfaceDark,
        border: Border(top: BorderSide(color: DyKalTheme.borderSoftDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DyKalTheme.backgroundDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DyKalTheme.borderSoftDark),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Tambah keterangan...',
                        hintStyle: TextStyle(color: DyKalTheme.textMutedDark, fontSize: 14),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  // Tombol 1x View Once di dalam input bar sebelah kanan
                  GestureDetector(
                    onTap: () => setState(() => _isViewOnce = !_isViewOnce),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isViewOnce ? DyKalTheme.primary : Colors.transparent,
                        border: Border.all(
                          color: _isViewOnce ? DyKalTheme.primary : DyKalTheme.textMutedDark,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: _isViewOnce ? Colors.white : DyKalTheme.textMutedDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: DyKalTheme.dykalGradient,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<_DoodlePoint?> points;
  _DoodlePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.point, points[i + 1]!.point, points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => true;
}
