import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../services/cloudinary_service.dart';
import '../../services/auth_service.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  Future<void> _upload(BuildContext context) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    final auth = AuthService();
    final coupleId = auth.coupleId;
    if (coupleId == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A))));
    try {
      for (final f in files) {
        final url = await CloudinaryService().uploadImage(File(f.path), folder: "dykal/album");
        if (url != null) {
          await FirebaseFirestore.instance.collection('couples/$coupleId/album').add({
            'url': url,
            'fromId': auth.myId,
            'fromName': auth.myName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload gagal: $e')));
    }
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto tersimpan ke album')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent, elevation: 0, floating: true,
          title: Row(children: [Icon(Icons.collections, color: DyKalTheme.textDark, size: 20), const SizedBox(width: 8), const Text("Album Kita")]),
          actions: [IconButton(onPressed: () => _upload(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: DyKalTheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 18)))],
        ),
        SliverToBoxAdapter(child: _header()),
        StreamBuilder<QuerySnapshot>(
          stream: coupleId == null ? null : FirebaseFirestore.instance.collection('couples/$coupleId/album').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
            final docs = snap.data!.docs;
            if (docs.isEmpty) return SliverFillRemaining(child: _empty());
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final url = data['url'] as String;
                    final isEven = i % 2 == 0;
                    return GestureDetector(
                      onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url))))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => Container(height: isEven ? 200 : 160, color: DyKalTheme.borderSoft)),
                          Positioned(bottom: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_today, size: 10, color: Colors.white), const SizedBox(width: 4), Text(_fmt(data['createdAt']), style: const TextStyle(color: Colors.white, fontSize: 10))]))),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Row(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.photo_camera_back, color: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Scrapbook Kita", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text("Tekan + untuk upload foto kalian. Tersimpan permanen & terenkripsi buat berdua.", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_a_photo, size: 64, color: DyKalTheme.textGrey.withOpacity(0.4)),
        const SizedBox(height: 12),
        const Text("Belum ada foto", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text("Upload foto pertama kalian 📸", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
      ]));

  String _fmt(dynamic ts) {
    try {
      final d = (ts as Timestamp).toDate();
      return "${d.day}/${d.month}/${d.year}";
    } catch (_) {
      return "";
    }
  }
}
