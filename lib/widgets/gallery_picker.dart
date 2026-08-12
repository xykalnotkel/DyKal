import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../config/theme.dart';
import '../screens/chat/camera_screen.dart';

/// Custom gallery picker (Batch H — rework total).
/// - Tiga kategori: SEMUA (foto+video campur, urut terbaru), Foto, Video.
/// - Lazy-load per 60 item saat scroll mendekati bawah (tidak berhenti di 150).
/// - Thumbnail 220px (cepat) — file asli tetap utuh saat dipilih.
/// - Mengembalikan File terpilih via Navigator.pop.
class GalleryPickerScreen extends StatefulWidget {
  final bool allowVideo;
  const GalleryPickerScreen({super.key, this.allowVideo = true});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  static const int _pageSize = 60;

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  int _tab = 0; // 0 = Semua, 1 = Foto, 2 = Video
  bool _loading = true;
  bool _loadingMore = false;
  bool _permissionDenied = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  RequestType get _reqType =>
      _tab == 2 ? RequestType.video : (_tab == 1 ? RequestType.image : RequestType.all);

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
      }
      return;
    }
    await _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(type: _reqType, hasAll: true);
    if (!mounted) return;
    // Kategori pertama hasAll=true adalah "Recent/Semua" — persis yang owner
    // minta: ngeload SEMUA gambar (dan video bila kategori Semua).
    setState(() {
      _albums = albums;
      _album = albums.isEmpty ? null : albums.first;
      _loading = false;
    });
    await _reload();
  }

  Future<void> _reload() async {
    _assets.clear();
    _page = 0;
    if (mounted) setState(() => _loadingMore = true);
    await _loadPage();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _loadPage() async {
    if (_album == null) return;
    try {
      final list = await _album!.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted || list.isEmpty) return;
      setState(() {
        _assets.addAll(list);
        _page++;
      });
    } catch (_) {}
  }

  Future<void> _switchTab(int t) async {
    if (t == _tab) return;
    setState(() {
      _tab = t;
      _loading = true;
      _assets.clear();
      _albums = [];
      _album = null;
    });
    await _loadAlbums();
  }

  bool _onScroll(ScrollNotification n) {
    // Infinite scroll: muat halaman berikutnya saat mendekati dasar.
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 600 &&
        !_loadingMore &&
        !_loading) {
      _loadingMore = true;
      _loadPage().whenComplete(() => _loadingMore = false);
    }
    return false;
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF24262B) : DyKalTheme.borderSoft;
    final segBg = isDark ? const Color(0xFF24262B) : Colors.grey.shade200;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih dari Galeri')),
      body: Column(children: [
        // Kategori: Semua / Foto / Video
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _seg('Semua', 0, Icons.grid_view_rounded, segBg),
            const SizedBox(width: 8),
            _seg('Foto', 1, Icons.photo_outlined, segBg),
            if (widget.allowVideo) ...[
              const SizedBox(width: 8),
              _seg('Video', 2, Icons.videocam_outlined, segBg),
            ],
          ]),
        ),
        // Dropdown album
        if (_albums.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DropdownButton<AssetPathEntity>(
              value: _album,
              isExpanded: true,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(16),
              items: _albums
                  .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (a) {
                setState(() => _album = a);
                _reload();
              },
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: DyKalTheme.primary))
              : _permissionDenied
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Izin galeri ditolak. Aktifkan dari pengaturan aplikasi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: DyKalTheme.textSecondaryOf(context)),
                        ),
                      ),
                    )
                  : _assets.isEmpty
                      ? Center(
                          child: Text(
                            _tab == 2 ? 'Tidak ada video' : (_tab == 1 ? 'Tidak ada foto' : 'Galeri kosong'),
                            style: TextStyle(color: DyKalTheme.textGrey),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(4),
                            cacheExtent: 900,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                            itemCount: _assets.length + 1,
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return _CameraTile(
                                  onTap: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CameraScreen()),
                                    );
                                    if (res != null && mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              }
                              final a = _assets[i - 1];
                              return _ThumbTile(
                                key: ValueKey(a.id),
                                asset: a,
                                tileBg: tileBg,
                                fmtDur: _fmtDur,
                                onTap: () async {
                                  final file = await a.file;
                                  if (file != null && mounted) Navigator.pop(context, file);
                                },
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _seg(String label, int idx, IconData icon, Color segBg) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? DyKalTheme.primary : segBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: active ? Colors.white : DyKalTheme.textGrey),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : DyKalTheme.textGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

/// Tile thumbnail dengan request gambar di-cache per-asset (scroll tak flicker).
class _ThumbTile extends StatefulWidget {
  final AssetEntity asset;
  final Color tileBg;
  final String Function(Duration) fmtDur;
  final VoidCallback onTap;
  const _ThumbTile(
      {super.key,
      required this.asset,
      required this.tileBg,
      required this.fmtDur,
      required this.onTap});

  @override
  State<_ThumbTile> createState() => _ThumbTileState();
}

class _ThumbTileState extends State<_ThumbTile> with AutomaticKeepAliveClientMixin {
  Uint8List? _thumb;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(220));
    if (mounted && t != null) setState(() => _thumb = t);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isVideo = widget.asset.type == AssetType.video;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: widget.tileBg,
        child: _thumb == null
            ? const SizedBox.expand()
            : Stack(fit: StackFit.expand, children: [
                Image.memory(_thumb!, fit: BoxFit.cover, gaplessPlayback: true),
                if (isVideo)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 11),
                        Text(widget.fmtDur(widget.asset.videoDuration),
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DyKalTheme.primary.withValues(alpha: 0.15),
          border: Border.all(color: DyKalTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: DyKalTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kamera',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DyKalTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
