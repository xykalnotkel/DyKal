import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_shape.dart';
import 'album_detail_screen.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  String get _coupleId => AuthService().coupleId ?? '';

  Future<void> _createAlbum(BuildContext context) async {
    final c = TextEditingController();
    PhotoShape shape = PhotoShape.love;
    final ok = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setS) => AlertDialog(
        title: const Text('Buat Album Baru'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Mis. Liburan, Anniversary...', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Bentuk cover:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: PhotoShape.values.map((s) => GestureDetector(
            onTap: () => setS(() => shape = s),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: shape == s ? DyKalTheme.primary : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Text(s.label, style: TextStyle(color: shape == s ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600))),
          )).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, {'name': c.text.trim(), 'shape': shape.name}), child: const Text('Buat')),
        ],
      )),
    );
    if (ok == null || (ok['name'] as String).isEmpty || _coupleId.isEmpty) return;
    await FirebaseFirestore.instance.collection('couples/$_coupleId/albums').add({
      'name': ok['name'],
      'shape': ok['shape'],
      'coverUrl': null,
      'createdBy': AuthService().myId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent, elevation: 0, floating: true,
            title: Row(children: [Icon(Icons.collections, color: DyKalTheme.primary, size: 22), const SizedBox(width: 8), const Text('Album Kita')]),
            actions: [
              IconButton(onPressed: () => _createAlbum(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 20))),
              const SizedBox(width: 8),
            ],
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _coupleId.isEmpty ? null : FirebaseFirestore.instance.collection('couples/$_coupleId/albums').snapshots(),
            builder: (context, snap) {
              if (_coupleId.isEmpty || snap.hasError) {
                return SliverFillRemaining(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Belum ada album. Tap + untuk membuat.', style: TextStyle(color: DyKalTheme.textGrey)))));
              }
              if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
              final docs = snap.data!.docs;
              if (docs.isEmpty) return SliverFillRemaining(child: _empty(context));
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;
                      final name = data['name'] as String? ?? 'Album';
                      final cover = data['coverUrl'] as String?;
                      final shape = shapeFromName(data['shape'] as String?);
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: id, albumName: name))),
                        child: Column(children: [
                          Expanded(child: Center(child: cover != null
                            ? ShapedPhoto(url: cover, shape: shape, size: 130)
                            : ClipPath(clipper: photoShapeClipper(shape), child: Container(width: 130, height: 130, decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient), child: const Center(child: Icon(Icons.photo_library, color: Colors.white70, size: 36))))))
                          ,
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ]),
                      );
                    },
                    childCount: docs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.82),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.collections_outlined, size: 64, color: DyKalTheme.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text('Belum ada album', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Buat album pertama kalian 💕', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
        ]),
      );
}
