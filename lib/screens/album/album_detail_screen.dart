import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/photo_shape.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumName;
  const AlbumDetailScreen({super.key, required this.albumId, required this.albumName});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  String get _coupleId => AuthService().coupleId ?? '';
  CollectionReference get _photos => FirebaseFirestore.instance.collection('couples/$_coupleId/albums/${widget.albumId}/photos');

  Future<void> _upload() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final shape = await _pickShape();
    if (shape == null) return;
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A))));
    try {
      final url = await CloudinaryService().uploadImage(File(x.path), folder: 'dykal/album/${widget.albumId}');
      if (url != null) {
        await _photos.add({
          'url': url,
          'shape': shape.name,
          'fromId': AuthService().myId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.doc('couples/$_coupleId/albums/${widget.albumId}').set({'coverUrl': url}, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto ditambahkan ✨')));
    }
  }

  Future<PhotoShape?> _pickShape() {
    return showModalBottomSheet<PhotoShape>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Pilih Bingkai Foto', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Row(children: PhotoShape.values.map((s) => Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, s),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(children: [
                  Image.asset(s.badgeAsset, width: 48, height: 48, errorBuilder: (_, __, ___) => Icon(s.icon, size: 40, color: DyKalTheme.primary)),
                  const SizedBox(height: 6),
                  Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ))).toList()),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent, elevation: 0, pinned: false, floating: true,
            title: Text(widget.albumName, style: const TextStyle(fontWeight: FontWeight.w700)),
            leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _photos.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
              final docs = snap.data!.docs;
              if (docs.isEmpty) return SliverFillRemaining(child: _empty());
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final url = data['url'] as String;
                      final shape = shapeFromName(data['shape'] as String?);
                      return Center(
                        child: GestureDetector(
                          onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url))))),
                          onLongPress: () async {
                            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Hapus foto?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red)))]));
                            if (ok == true) await docs[i].reference.delete();
                          },
                          child: ShapedPhoto(url: url, shape: shape, size: 150),
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: DyKalTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Upload'),
      ),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_a_photo, size: 64, color: DyKalTheme.primary.withOpacity(0.4)),
        const SizedBox(height: 12),
        const Text('Album masih kosong', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Upload foto pertama dengan bingkai bentuk ✨', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12), textAlign: TextAlign.center),
      ]));
}
