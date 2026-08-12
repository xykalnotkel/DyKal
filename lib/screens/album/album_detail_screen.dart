import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/e2e_service.dart';
import '../../widgets/offline_first_image.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/gallery_picker.dart';
import '../../widgets/fullscreen_media_viewer.dart';

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
  bool _isUploading = false;

  Future<void> _upload() async {
    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: true)),
    );
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final isVid = _looksVideoFile(file.path);
      // BATCH L: album ikut E2EE — foto dikompres+enkripsi, video (<=150MB) dienkripsi
      // apa adanya, lalu diupload sebagai blob RAW (marker /dykal/e2e/). Media lama
      // plaintext tetap tampil normal (render sadar marker).
      String? url;
      if (isVid) {
        final len = await file.length();
        if (len <= 150 * 1024 * 1024) {
          final enc = await E2EService.encryptFile(file);
          if (enc != null) url = await CloudinaryService().uploadRaw(enc);
        } // video >150MB -> fallback plaintext (RAM low-end dijaga)
        url ??= await CloudinaryService().uploadVideoForAudio(file, folder: 'dykal/album/${widget.albumId}');
      } else {
        final enc = await E2EService.encryptFile(await CloudinaryService().compressImage(file));
        if (enc != null) url = await CloudinaryService().uploadRaw(enc);
        url ??= await CloudinaryService().uploadImage(file, folder: 'dykal/album/${widget.albumId}');
      }
      if (url != null) {
        await _photos.add({
          'url': url,
          'kind': isVid ? 'video' : 'image',
          'fromId': AuthService().myId,
          'fromName': AuthService().myName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!isVid) {
          await FirebaseFirestore.instance
              .doc('couples/$_coupleId/albums/${widget.albumId}')
              .set({'coverUrl': url}, SetOptions(merge: true));
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isUploading = false);
  }

  static bool _looksVideoFile(String p) =>
      RegExp(r'\.(mp4|mov|3gp|mkv|webm)(\?|#|\$)', caseSensitive: false).hasMatch(p);

  void _openMedia(String url, String fromName, DateTime? createdAt, DocumentReference ref, {bool isVideo = false}) {
    FullscreenMediaViewer.open(
      context,
      url: url,
      fromName: fromName,
      createdAt: createdAt,
      isVideo: isVideo,
      onDelete: () => ref.delete(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            title: Text(widget.albumName, style: const TextStyle(fontWeight: FontWeight.w700)),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                onPressed: _upload,
                icon: const Icon(Icons.add_a_photo, color: DyKalTheme.primary),
              ),
            ],
          ),
          if (_isUploading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: LinearProgressIndicator(color: DyKalTheme.primary),
              ),
            ),
          StreamBuilder<QuerySnapshot>(
            stream: _photos.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('Gagal memuat album', style: TextStyle(color: DyKalTheme.textGrey)),
                  ),
                );
              }
              if (!snap.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: DyKalTheme.primary),
                    ),
                  ),
                );
              }
              final rawDocs = snap.data!.docs;
              rawDocs.sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)['createdAt'];
                final tb = (b.data() as Map<String, dynamic>)['createdAt'];
                if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                return 0;
              });

              if (rawDocs.isEmpty) return SliverFillRemaining(child: _empty());

              return SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final data = rawDocs[i].data() as Map<String, dynamic>;
                      final url = data['url'] as String;
                      final fromName = (data['fromName'] as String?) ?? '';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final isVid = (data['kind'] as String? ?? (_looksVideoFile(url) ? 'video' : 'image')) == 'video';

                      return GestureDetector(
                        onTap: () => _openMedia(url, fromName, createdAt, rawDocs[i].reference, isVideo: isVid),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isVid
                                ? Container(
                                    color: DyKalTheme.surfaceDark,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 40),
                                    ),
                                  )
                                : OfflineFirstImage(url: url, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                    childCount: rawDocs.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
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
        label: const Text('Upload Media'),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 64, color: DyKalTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Album masih kosong', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Upload foto pertama kalian bersama', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
          ],
        ),
      );
}
