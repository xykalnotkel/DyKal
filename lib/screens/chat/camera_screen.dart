import 'dart:io';
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

  Future<void> _setupController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (_) {}
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

  void _flipCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    _setupController(_cameras[_selectedCameraIdx]);
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

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xFile = await _controller!.takePicture();
      final capturedFile = File(xFile.path);
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
    } catch (_) {}
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
            // Live Camera Preview
            Positioned.fill(
              child: _isInit && _controller != null
                  ? (filter == null
                      ? CameraPreview(_controller!)
                      : ColorFiltered(
                          colorFilter: filter,
                          child: CameraPreview(_controller!),
                        ))
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
