import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../config/theme.dart';

/// Custom gallery picker: dropdown album + grid thumbnail + pisah Foto/Video.
/// Mengembalikan File terpilih via Navigator.pop.
class GalleryPickerScreen extends StatefulWidget {
  final bool allowVideo;
  const GalleryPickerScreen({super.key, this.allowVideo = true});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  List<AssetEntity> _assets = [];
  int _tab = 0; // 0 = foto, 1 = video
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadAlbums();
  }

  RequestType get _reqType => _tab == 1 ? RequestType.video : RequestType.image;

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(type: _reqType, hasAll: true);
    if (!mounted) return;
    setState(() {
      _albums = albums;
      _album = albums.isEmpty ? null : albums.first;
      _loading = false;
    });
    await _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (_album == null) {
      if (mounted) setState(() => _assets = []);
      return;
    }
    final list = await _album!.getAssetListPaged(page: 0, size: 150);
    if (mounted) setState(() => _assets = list);
  }

  Future<void> _switchTab(int t) async {
    setState(() { _tab = t; _loading = true; });
    await _loadAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih dari Galeri'),
        actions: [
          IconButton(
            icon: Icon(_tab == 0 ? Icons.videocam_outlined : Icons.photo_outlined),
            tooltip: _tab == 0 ? 'Lihat Video' : 'Lihat Foto',
            onPressed: () => _switchTab(_tab == 0 ? 1 : 0),
          ),
        ],
      ),
      body: Column(children: [
        // Toggle Foto / Video
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            _seg('Foto', 0, Icons.photo_outlined),
            const SizedBox(width: 8),
            if (widget.allowVideo) _seg('Video', 1, Icons.videocam_outlined),
          ]),
        ),
        // Dropdown album
        if (_albums.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButton<AssetPathEntity>(
              value: _album,
              isExpanded: true,
              underline: const SizedBox(),
              items: _albums.map((a) => DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (a) { setState(() => _album = a); _loadAssets(); },
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))
              : _assets.isEmpty
                  ? Center(child: Text('Tidak ada ${_tab == 1 ? 'video' : 'foto'}', style: TextStyle(color: DyKalTheme.textGrey)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                      itemCount: _assets.length,
                      itemBuilder: (_, i) {
                        final a = _assets[i];
                        return FutureBuilder<Uint8List?>(
                          future: a.thumbnailDataWithSize(const ThumbnailSize.square(300)),
                          builder: (_, snap) {
                            if (snap.data == null) return Container(color: DyKalTheme.borderSoft);
                            return GestureDetector(
                              onTap: () async {
                                final file = await a.file;
                                if (file != null && mounted) Navigator.pop(context, file);
                              },
                              child: Stack(fit: StackFit.expand, children: [
                                Image.memory(snap.data!, fit: BoxFit.cover),
                                if (a.type == AssetType.video) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
                              ]),
                            );
                          },
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _seg(String label, int idx, IconData icon) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? Colors.white : DyKalTheme.textGrey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.white : DyKalTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
