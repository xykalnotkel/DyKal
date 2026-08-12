import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../config/theme.dart';
import '../../widgets/gallery_picker.dart';
import 'image_send_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isRecording = false;
  FlashMode _flashMode = FlashMode.auto;
  bool _isInit = false;
  String _activeFilter = 'none';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupController(_cameras[_selectedCameraIdx]);
      }
    } catch (_) {}
  }

  bool _switching = false; // guard anti double-tap saat ganti kamera

  Future<void> _setupController(CameraDescription camera) async {
    // BATCH H (keluhan owner: switch kamera belakang malah STUCK):
    // akar bug — controller LAMA di-dispose tapi _isInit tetap true, jadi
    // CameraPreview merender controller mati (preview beku). Plus flip tak
    // di-await -> dua initialize berpotongan. Sekarang: state dimatikan dulu,
    // dispose di-await, init baru di-await, baru preview nyala lagi.
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _isInit = false);
    try { await old?.dispose(); } catch (_) {}

    final next = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await next.initialize();
      if (!mounted) { try { await next.dispose(); } catch (_) {} return; }
      setState(() {
        _controller = next;
        _isInit = true;
      });
    } catch (_) {
      try { await next.dispose(); } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) {
        _setupController(_cameras[_selectedCameraIdx]);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _switching) return;
    _switching = true;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIdx]);
    _switching = false;
  }

  void _toggleFlash() async {
    if (_controller == null) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
      default:
        nextMode = FlashMode.auto;
        break;
    }
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_selectedCameraIdx].lensDirection == CameraLensDirection.front;

  /// Mirror gambar hasil jepret kamera depan agar hasil = apa yang terlihat
  /// di preview (WYSIWYG, seperti WhatsApp).
  Future<File> _mirrorImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      // FIX (owner): hindari OOM pada foto resolusi tinggi (12MP+) dengan membatasi
      // dimensi dekoding ke maksimal 1440px lebar/tinggi.
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1440);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(img.width.toDouble(), 0);
      canvas.scale(-1, 1);
      canvas.drawImage(img, Offset.zero, Paint());
      final pic = recorder.endRecording();
      final mirrored = await pic.toImage(img.width, img.height);
      final byteData = await mirrored.toByteData(format: ui.ImageByteFormat.png);
      final outPath = '${file.path}.mirror.png';
      await File(outPath).writeAsBytes(byteData!.buffer.asUint8List());
      return File(outPath);
    } catch (_) {
      return file;
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xFile = await _controller!.takePicture();
      var capturedFile = File(xFile.path);
      if (_isFrontCamera) capturedFile = await _mirrorImage(capturedFile);
      if (!mounted) return;

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageSendScreen(image: capturedFile),
        ),
      );

      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (_) {
      // FIX: dulu gagal jepret diam-diam (terasa "berantakan"). Sekarang kasih tahu.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto, coba lagi')),
        );
      }
    }
  }

  Future<void> _openGallery() async {
    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: true)),
    );
    if (file == null || !mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageSendScreen(image: file),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  ColorFilter? _getFilter(String f) {
    switch (f) {
      case 'warm':
        return ColorFilter.mode(const Color(0xFFFFE0B2).withValues(alpha: 0.3), BlendMode.overlay);
      case 'cool':
        return ColorFilter.mode(const Color(0xFFB2EBF2).withValues(alpha: 0.25), BlendMode.overlay);
      case 'bw':
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _getFilter(_activeFilter);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Live Camera Preview (cover-crop, tidak distorsi, mirror bila kamera depan)
            Positioned.fill(
              child: _isInit && _controller != null
                  ? _buildPreview(filter)
                  : const Center(
                      child: CircularProgressIndicator(color: DyKalTheme.primary),
                    ),
            ),

            // Top Flash & Filter Toolbar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.auto
                          ? Icons.flash_auto
                          : (_flashMode == FlashMode.always ? Icons.flash_on : Icons.flash_off),
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ],
              ),
            ),

            // Bottom Filter Bar & Controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _filterChip('none', 'Normal', Icons.auto_awesome),
                        _filterChip('warm', 'Warm', Icons.wb_sunny),
                        _filterChip('cool', 'Cool', Icons.ac_unit),
                        _filterChip('bw', 'B&W', Icons.dark_mode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3 Main Bottom Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Galeri
                        GestureDetector(
                          onTap: _openGallery,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1.5),
                            ),
                            child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                          ),
                        ),

                        // Center: Shutter Button
                        GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3.5),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.red : Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                        // Right: Flip Camera
                        GestureDetector(
                          onTap: _flipCamera,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1.5),
                            ),
                            child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Preview kamera mengisi layar TANPA distorsi + dicerminkan saat kamera depan.
  /// FIX (laporan owner "gepeng"): aspectRatio kamera Android dilaporkan dalam
  /// orientasi SENSOR (landscape), kalau dipakai mentah utk layar portrait
  /// hasilnya gepeng/zoom aneh. Solusi: pakai previewSize yang ditukar sisinya
  /// + FittedBox cover — pola baku kamera Flutter.
  Widget _buildPreview(ColorFilter? filter) {
    final controller = _controller!;
    Widget preview = CameraPreview(controller);
    if (_isFrontCamera) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: preview,
      );
    }

    if (filter != null) {
      preview = ColorFiltered(colorFilter: filter, child: preview);
    }

    final ps = controller.value.previewSize;
    if (ps == null) return Center(child: preview);

    // previewSize hidup dalam koordinat sensor (lebar > tinggi di ponsel portrait
    // umumnya). Di layar portrait: lebar widget = tinggi sensor, dst.
    final w = ps.height;
    final h = ps.width;

    if (_isFrontCamera) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: preview,
      );
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: w, height: h, child: preview),
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    final active = _activeFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? DyKalTheme.primary : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? DyKalTheme.primary : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
