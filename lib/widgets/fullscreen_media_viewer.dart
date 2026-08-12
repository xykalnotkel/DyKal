import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'offline_first_image.dart';
import 'inline_video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/media_saver.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final String url;
  final String? fromName;
  final DateTime? createdAt;
  final bool isVideo;
  final VoidCallback? onDelete;

  const FullscreenMediaViewer({
    super.key,
    required this.url,
    this.fromName,
    this.createdAt,
    this.isVideo = false,
    this.onDelete,
  });

  static void open(
    BuildContext context, {
    required String url,
    String? fromName,
    DateTime? createdAt,
    bool isVideo = false,
    VoidCallback? onDelete,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FullscreenMediaViewer(
          url: url,
          fromName: fromName,
          createdAt: createdAt,
          isVideo: isVideo,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  static const _secCh = MethodChannel('dykal/secure_screen');

  bool _showControls = true;
  double _verticalOffset = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.fromName == 'Foto Sekali Lihat') {
      try { _secCh.invokeMethod('enable'); } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (widget.fromName == 'Foto Sekali Lihat') {
      try { _secCh.invokeMethod('disable'); } catch (_) {}
    }
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    final savedPath = await MediaSaver.save(
      widget.url,
      type: widget.isVideo ? 'video' : 'foto',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath != null
              ? 'Media berhasil disimpan ke Galeri HP'
              : 'Gagal menyimpan media',
        ),
      ),
    );
  }

  Future<void> _shareMedia() async {
    try {
      final localFile = await MediaSaver.save(
        widget.url,
        type: widget.isVideo ? 'video' : 'foto',
      );
      if (localFile != null) {
        await Share.shareXFiles([XFile(localFile)], text: 'Dibagikan dari DyKal');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(widget.createdAt!)
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragUpdate: (details) {
          setState(() => _verticalOffset += details.delta.dy);
        },
        onVerticalDragEnd: (details) {
          if (_verticalOffset.abs() > 100) {
            Navigator.pop(context);
          } else {
            setState(() => _verticalOffset = 0);
          }
        },
        child: Stack(
          children: [
            // Center Zoomable Media
            Center(
              child: Transform.translate(
                offset: Offset(0, _verticalOffset),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.5,
                  child: widget.isVideo
                      ? InlineVideoPlayer(url: widget.url)
                      : OfflineFirstImage(
                          url: widget.url,
                          fit: BoxFit.contain,
                          placeholder: const Center(
                            child: CircularProgressIndicator(color: DyKalTheme.primary, strokeWidth: 2.5),
                          ),
                        ),
                ),
              ),
            ),

            // Top AppBar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 12,
                  right: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.fromName != null && widget.fromName!.isNotEmpty)
                            Text(
                              widget.fromName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: DyKalTheme.textMutedDark,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 12,
                  left: 24,
                  right: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: widget.fromName == 'Foto Sekali Lihat'
                      ? [
                          _buildActionButton(
                            icon: Icons.check_circle_outline,
                            label: 'Tutup & Hapus',
                            color: const Color(0xFF00D68F),
                            onTap: () {
                              Navigator.pop(context);
                              if (widget.onDelete != null) widget.onDelete!();
                            },
                          ),
                        ]
                      : [
                          _buildActionButton(
                            icon: Icons.download_rounded,
                            label: 'Simpan',
                            loading: _isSaving,
                            onTap: _saveToGallery,
                          ),
                          _buildActionButton(
                            icon: Icons.share_rounded,
                            label: 'Bagikan',
                            onTap: _shareMedia,
                          ),
                          if (widget.onDelete != null)
                            _buildActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Hapus',
                              color: Colors.redAccent,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onDelete!();
                              },
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DyKalTheme.surfaceDark.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
