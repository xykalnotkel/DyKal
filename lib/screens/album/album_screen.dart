import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_shape.dart';
import 'album_detail_screen.dart';
import '../../widgets/dykal_loading.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  String get _coupleId => AuthService().coupleId ?? '';

  Future<void> _createAlbum(BuildContext context) async {
    final c = TextEditingController();
    PhotoShape shape = PhotoShape.love;
    // Bottom sheet (bukan popup) sesuai permintaan
    final ok = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: StatefulBuilder(builder: (_, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: DyKalTheme.borderSoftDark, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              const Text('Buat Album Baru', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: c,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Mis. Liburan, Anniversary...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: DyKalTheme.backgroundDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Bentuk cover:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: PhotoShape.values.map((s) => GestureDetector(
                  onTap: () => setS(() => shape = s),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shape == s ? DyKalTheme.primary.withValues(alpha: 0.2) : DyKalTheme.backgroundDark,
                        border: Border.all(color: shape == s ? DyKalTheme.primary : DyKalTheme.borderSoftDark, width: 2),
                      ),
                      child: ClipPath(
                        clipper: photoShapeClipper(s),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient),
                          child: Icon(s.icon, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.label, style: TextStyle(color: shape == s ? Colors.white : Colors.white54, fontSize: 10)),
                  ]),
                )).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, {'name': c.text.trim(), 'shape': shape.name}),
                    child: const Text('Buat'),
                  )),
                ],
              ),
            ],
          )),
        ),
      ),
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
              if (!snap.hasData) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: DyKalSpinner()));
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
          Icon(Icons.collections_outlined, size: 64, color: DyKalTheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Belum ada album', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Buat album pertama kalian', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
        ]),
      );
}
