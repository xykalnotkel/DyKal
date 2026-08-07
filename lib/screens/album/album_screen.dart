import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../config/theme.dart';
import '../../services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  Future<void> _upload(BuildContext context) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: DyKalTheme.primary)));
    for (var f in files) {
      await CloudinaryService().uploadImage(File(f.path), folder: "dykal/album");
    }
    if (context.mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Colors.white, size: 18), SizedBox(width: 8), Text("Foto berhasil diupload ke Cloudinary")])));
  }

  @override
  Widget build(BuildContext context) {
    final photos = List.generate(8, (i) => "https://picsum.photos/seed/dykal$i/600/800");

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent, elevation: 0, floating: true,
          title: Row(children: [
            Icon(PhosphorIcons.images(PhosphorIconsStyle.regular), color: DyKalTheme.textDark, size: 20),
            SizedBox(width: 8),
            Text("Album Kita"),
          ]),
          actions: [IconButton(onPressed: () => _upload(context), icon: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: DyKalTheme.primary, borderRadius: BorderRadius.circular(12)), child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: Colors.white, size: 18)))],
        ),

        // HEADER ALBUM dengan overlay penghias - custom 320x140
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DyKalTheme.borderSoft),
              // Overlay decoration sebagai background pattern halus
              image: DecorationImage(
                image: AssetImage('assets/illustrations/webp/album_overlay.webp'),
                fit: BoxFit.cover,
                opacity: 0.08, // sangat tipis sebagai penghias
                alignment: Alignment.center,
              ),
            ),
            child: Stack(
              children: [
                // Decorative floating hearts overlay - positioned
                Positioned(top: 12, right: 16, child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: DyKalTheme.primary.withOpacity(0.18), size: 18)),
                Positioned(bottom: 16, left: 14, child: Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: DyKalTheme.accent.withOpacity(0.5), size: 12)),
                Positioned(top: 36, left: 22, child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: DyKalTheme.secondary.withOpacity(0.25), size: 10)),
                // Konten header
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    // Ilustrasi album_overlay mini 80x80 di kiri sebagai penghias utama
                    Container(
                      width: 86, height: 86,
                      decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderSoft)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset('assets/illustrations/webp/album_overlay.webp', fit: BoxFit.cover),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Row(children: [
                        Icon(PhosphorIcons.bookOpen(PhosphorIconsStyle.regular), size: 14, color: DyKalTheme.primary),
                        SizedBox(width: 6),
                        Text("Scrapbook Kita", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                      SizedBox(height: 4),
                      Text("8 foto • Update 7 Aug", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIcons.images(PhosphorIconsStyle.fill), size: 12, color: DyKalTheme.primary),
                          SizedBox(width: 4),
                          Text("Lihat semua", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DyKalTheme.primary)),
                        ]),
                      ),
                    ])),
                  ]),
                ),
              ],
            ),
          ),
        ),

        if (photos.isEmpty)
          SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset('assets/illustrations/webp/album_empty.webp', width: 180, height: 180, fit: BoxFit.contain),
            SizedBox(height: 12),
            Text("Belum ada foto", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(PhosphorIcons.camera(PhosphorIconsStyle.regular), size: 14, color: DyKalTheme.textGrey),
              SizedBox(width: 6),
              Text("Upload foto pertama kalian", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
            ]),
            SizedBox(height: 16),
            // Penghias bawah empty state
            Image.asset('assets/illustrations/webp/album_overlay.webp', width: 140, height: 60, fit: BoxFit.contain, opacity: AlwaysStoppedAnimation(0.35)),
          ])))
        else
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Grid tetap
                Padding(
                  padding: EdgeInsets.all(12),
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      final isEven = i % 2 == 0;
                      return GestureDetector(
                        onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: photos[i])))),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(children: [
                                CachedNetworkImage(imageUrl: photos[i], fit: BoxFit.cover, placeholder: (_, __) => Container(height: isEven ? 200 : 160, color: DyKalTheme.borderSoft)),
                                Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 40, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent])))),
                                Positioned(bottom: 8, left: 8, right: 8, child: Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular), size: 10, color: Colors.white), SizedBox(width: 4), Text("7 Aug 2026", style: TextStyle(color: Colors.white, fontSize: 10))]))),
                              ]),
                            ),
                            // tape pojok foto
                            Positioned(
                              top: -6, left: 12,
                              child: Container(
                                width: 44, height: 14,
                                decoration: BoxDecoration(color: isEven ? DyKalTheme.accent.withOpacity(0.9) : DyKalTheme.primary.withOpacity(0.85), borderRadius: BorderRadius.circular(4)),
                                child: Center(child: Icon(isEven ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 8, color: Colors.white)),
                              ),
                            ),
                            Positioned(top: 8, right: 8, child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle), child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 10, color: DyKalTheme.primary))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // === ELEMEN POJOK DI ATAS GRID - kayak stiker pojokan ===
                // Pojok kiri atas
                Positioned(top: 0, left: 6, child: _cornerSticker(PhosphorIcons.heart(PhosphorIconsStyle.fill), DyKalTheme.primary, 22)),
                // Pojok kanan atas
                Positioned(top: 2, right: 8, child: _cornerSticker(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), DyKalTheme.accent, 16)),
                // Pojok kiri bawah (di atas footer)
                Positioned(bottom: 4, left: 10, child: _cornerSticker(PhosphorIcons.star(PhosphorIconsStyle.fill), DyKalTheme.secondary, 14)),
                // Pojok kanan bawah
                Positioned(bottom: 6, right: 12, child: _cornerSticker(PhosphorIcons.heart(PhosphorIconsStyle.fill), DyKalTheme.primary.withOpacity(0.7), 18)),
              ],
            ),
          ),

        // FOOTER PENGHIAS ALBUM - full width decorative
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
            height: 72,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Stack(
              children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/illustrations/webp/album_overlay.webp', fit: BoxFit.cover, opacity: AlwaysStoppedAnimation(0.07)))),
                Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: DyKalTheme.accent, size: 14),
                  SizedBox(width: 8),
                  Text("Kenangan manis kalian", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  SizedBox(width: 8),
                  Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: DyKalTheme.primary, size: 14),
                ])),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // Stiker pojok grid - dekorasi overlay di 4 sudut
  Widget _cornerSticker(IconData icon, Color color, double size) {
    return Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: Icon(icon, color: color, size: size * 0.6)),
    );
  }
}
