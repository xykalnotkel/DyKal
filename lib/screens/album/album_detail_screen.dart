import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/gallery_picker.dart';
import '../../services/media_saver.dart';

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
    final file = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: true)));
    if (file == null) return;
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A))));
    try {
      final url = await CloudinaryService().uploadImage(file, folder: 'dykal/album/${widget.albumId}');
      if (url != null) {
        await _photos.add({'url': url, 'fromId': AuthService().myId, 'fromName': AuthService().myName, 'createdAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.doc('couples/$_coupleId/albums/${widget.albumId}').set({'coverUrl': url}, SetOptions(merge: true));
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _openViewer(String url, DocumentReference ref) {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.black, child: Stack(children: [
      InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
      Positioned(top: 12, right: 12, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white))),
      Positioned(left: 0, right: 0, bottom: 16, child: Center(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(28)), child: Row(mainAxisSize: MainAxisSize.min, children: [
        _viewerBtn(Icons.download, 'Simpan', () async { Navigator.pop(context); final p = await MediaSaver.save(url, type: 'Foto'); _toast(p == null ? 'Gagal menyimpan' : 'Tersimpan ✅'); }),
        const SizedBox(width: 12),
        _viewerBtn(Icons.share, 'Bagikan', () async { Navigator.pop(context); await _share(url); }),
        const SizedBox(width: 12),
        _viewerBtn(Icons.delete, 'Hapus', () { Navigator.pop(context); ref.delete(); }, red: true),
      ])))),
    ])));
  }

  Widget _viewerBtn(IconData icon, String label, VoidCallback onTap, {bool red = false}) => GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: red ? Colors.redAccent : Colors.white, size: 24), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))]));

  Future<void> _share(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(url, path);
      await Share.shareXFiles([XFile(path)]);
    } catch (_) {}
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(backgroundColor: Colors.transparent, elevation: 0, floating: true, title: Text(widget.albumName, style: const TextStyle(fontWeight: FontWeight.w700)), leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)), actions: [IconButton(onPressed: _upload, icon: const Icon(Icons.add_a_photo, color: Color(0xFFFF6B8A)))]),
          StreamBuilder<QuerySnapshot>(
            stream: _photos.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return SliverFillRemaining(child: Center(child: Text('Gagal memuat. Cek rules Firestore.', style: TextStyle(color: DyKalTheme.textGrey))));
              if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
              final rawDocs = snap.data!.docs;
              rawDocs.sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)['createdAt'];
                final tb = (b.data() as Map<String, dynamic>)['createdAt'];
                if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                return 0;
              });
              final docs = rawDocs;
              if (docs.isEmpty) return SliverFillRemaining(child: _empty());
              return SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final url = data['url'] as String;
                    return GestureDetector(
                      onTap: () => _openViewer(url, docs[i].reference),
                      onLongPress: () => _openViewer(url, docs[i].reference),
                      child: Padding(padding: const EdgeInsets.all(4), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => Container(color: DyKalTheme.borderSoft)))),
                    );
                  }, childCount: docs.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
      floatingActionButton: Padding(padding: const EdgeInsets.only(bottom: 8), child: FloatingActionButton.extended(onPressed: _upload, backgroundColor: DyKalTheme.primary, foregroundColor: Colors.white, icon: const Icon(Icons.add_a_photo), label: const Text('Upload Foto'))),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_a_photo, size: 64, color: DyKalTheme.primary.withOpacity(0.4)),
        const SizedBox(height: 12),
        const Text('Album masih kosong', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Upload foto pertama ✨', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12), textAlign: TextAlign.center),
      ]));
}
