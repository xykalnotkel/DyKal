import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import 'album_detail_screen.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  String get _coupleId => AuthService().coupleId ?? '';

  Future<void> _createAlbum(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buat Album Baru'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Mis. Liburan, Anniversary...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Buat')),
        ],
      ),
    );
    if (name == null || name.isEmpty || _coupleId.isEmpty) return;
    await FirebaseFirestore.instance.collection('couples/$_coupleId/albums').add({
      'name': name,
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
              IconButton(onPressed: () => _createAlbum(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 18))),
            ],
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('couples/$_coupleId/albums').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (_coupleId.isEmpty || snap.hasError) {
                return SliverFillRemaining(child: _empty(context));
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
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: id, albumName: name))),
                        child: Container(
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? DyKalTheme.borderSoftDark : DyKalTheme.borderSoft)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: cover != null
                                    ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, placeholder: (_, __) => Container(color: DyKalTheme.borderSoft))
                                    : Container(
                                        decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient),
                                        child: const Center(child: Icon(Icons.photo_library, color: Colors.white70, size: 36)),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection('couples/$_coupleId/albums/$id/photos').snapshots(),
                                  builder: (_, s) => Row(children: [Icon(Icons.photo, size: 13, color: DyKalTheme.textGrey), const SizedBox(width: 3), Text('${s.data?.docs.length ?? 0}', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12))]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.78),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAlbum(context),
        backgroundColor: DyKalTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Buat Album'),
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
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _createAlbum(context), icon: const Icon(Icons.add), label: const Text('Buat Album')),
        ]),
      );
}
