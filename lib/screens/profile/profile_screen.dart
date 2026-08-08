import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/birthday_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/theme_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return StreamBuilder<DocumentSnapshot>(
      stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final nameA = (d?['displayNameA'] as String?) ?? 'Aku';
        final nameB = (d?['displayNameB'] as String?) ?? 'Ayang';
        final photoA = d?['photoA'] as String?;
        final photoB = d?['photoB'] as String?;
        final bA = (d?['birthdayA'] as Timestamp?)?.toDate();
        final bB = (d?['birthdayB'] as Timestamp?)?.toDate();
        final ann = (d?['anniversary'] as Timestamp?)?.toDate();
        return CustomScrollView(slivers: [
          SliverAppBar(backgroundColor: Colors.transparent, elevation: 0, floating: true, title: const Text("Profil & Pengaturan")),
          SliverToBoxAdapter(child: _coupleCard(nameA, nameB, photoA, photoB)),
          SliverToBoxHeader(label: "Tanggal Penting"),
          SliverToBoxAdapter(child: _dateTile(context, Icons.favorite, "Anniversary", ann, () async {
            final picked = await _pick(context, ann);
            if (picked != null) await FirebaseFirestore.instance.doc('couples/$coupleId').update({'anniversary': Timestamp.fromDate(picked)});
          })),
          SliverToBoxAdapter(child: _dateTile(context, Icons.cake, "Ulang Tahun $nameA", bA, () async {
            final picked = await _pick(context, bA);
            if (picked != null) await FirebaseFirestore.instance.doc('couples/$coupleId').update({'birthdayA': Timestamp.fromDate(picked)});
          })),
          SliverToBoxAdapter(child: _dateTile(context, Icons.cake_outlined, "Ulang Tahun $nameB", bB, () async {
            final picked = await _pick(context, bB);
            if (picked != null) await FirebaseFirestore.instance.doc('couples/$coupleId').update({'birthdayB': Timestamp.fromDate(picked)});
          })),
          if (bA != null && bB != null) SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () async { await BirthdayService().saveBirthdays(birthdayA: bA, birthdayB: bB); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifikasi ulang tahun dijadwalkan ✅'))); },
              icon: const Icon(Icons.notifications_active, size: 16), label: const Text('Jadwalkan Notif Ulang Tahun'),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxHeader(label: "Tampilan"),
          SliverToBoxAdapter(child: _themeSelector()),
          SliverToBoxHeader(label: "Akun"),
          SliverToBoxAdapter(child: _editProfileTile(context)),
          SliverToBoxAdapter(child: _account(context, nameA)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]);
      },
    );
  }

  Widget _coupleCard(String a, String b, String? photoA, String? photoB) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _avatar(photoA, a),
            const SizedBox(height: 8),
            Text(a, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ])),
          const Icon(Icons.favorite, color: Colors.white, size: 28),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _avatar(photoB, b),
            const SizedBox(height: 8),
            Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ])),
        ]),
      );

  Widget _avatar(String? photo, String name) => CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white.withOpacity(0.25),
        backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
        child: photo == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800)) : null,
      );

  Widget _dateTile(BuildContext context, IconData icon, String label, DateTime? value, VoidCallback onTap) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: DyKalTheme.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(value == null ? 'Belum diatur • ketuk untuk set' : '${value.day}/${value.month}/${value.year}', style: TextStyle(color: value == null ? DyKalTheme.textGrey : DyKalTheme.primary, fontSize: 12)),
                ])),
                Icon(Icons.chevron_right, color: DyKalTheme.textGrey, size: 20),
              ]),
            ),
          ),
        ),
      );

  Widget _account(BuildContext context, String name) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), tileColor: Colors.white,
            leading: CircleAvatar(backgroundColor: DyKalTheme.primary.withOpacity(0.15), child: Icon(Icons.person, color: DyKalTheme.primary)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: const Text('Keluar?'), content: const Text('Kamu akan keluar dari akun ini.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Keluar'))],
              ));
              if (ok == true) await AuthService().logout();
            },
            icon: const Icon(Icons.logout), label: const Text('Keluar'),
          )),
        ]),
      );

  Widget _themeSelector() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            final m = ThemeController.instance.mode;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            Widget chip(IconData icon, String label, ThemeMode mode) {
              final active = m == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => ThemeController.instance.set(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Icon(icon, size: 18, color: active ? Colors.white : (isDark ? Colors.white70 : DyKalTheme.textGrey)),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : (isDark ? Colors.white70 : DyKalTheme.textGrey))),
                    ]),
                  ),
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: isDark ? DyKalTheme.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? DyKalTheme.borderSoftDark : DyKalTheme.borderSoft)),
              child: Row(children: [
                chip(Icons.brightness_auto, 'Sistem', ThemeMode.system),
                chip(Icons.light_mode_outlined, 'Terang', ThemeMode.light),
                chip(Icons.dark_mode_outlined, 'Gelap', ThemeMode.dark),
              ]),
            );
          },
        ),
      );

  Widget _editProfileTile(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: DyKalTheme.primary.withOpacity(0.15), child: Icon(Icons.edit, color: DyKalTheme.primary)),
            title: const Text('Edit Nama & Foto', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Ubah profil kamu (real-time)', style: TextStyle(fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: DyKalTheme.textGrey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => _editProfile(context),
          ),
        ),
      );

  Future<void> _editProfile(BuildContext context) async {
    final auth = AuthService();
    final coupleId = auth.coupleId ?? '';
    final myId = auth.myId;
    final nameCtl = TextEditingController(text: auth.myName);
    String? photoUrl = auth.myPhotoUrl;
    File? picked;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (s) => StatefulBuilder(builder: (s, setS) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(s).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: DyKalTheme.borderSoft, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (x != null) setS(() => picked = File(x.path));
            },
            child: CircleAvatar(radius: 42, backgroundColor: DyKalTheme.primary.withOpacity(0.15), backgroundImage: picked != null ? FileImage(picked!) as ImageProvider : (photoUrl != null ? CachedNetworkImageProvider(photoUrl) as ImageProvider : null), child: (picked == null && photoUrl == null) ? Icon(Icons.person, size: 40, color: DyKalTheme.primary) : null),
          ),
          const SizedBox(height: 8),
          Text('Ketuk foto untuk ganti', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(controller: nameCtl, decoration: const InputDecoration(hintText: 'Nama panggilan', filled: true, fillColor: Color(0xFFFFF8F9), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () async {
              final newName = nameCtl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(s);
              String? newPhoto = photoUrl;
              if (picked != null) newPhoto = await CloudinaryService().uploadImage(picked!, folder: 'dykal/avatar');
              await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
              await FirebaseFirestore.instance.doc('users/$myId').set({'displayName': newName, 'photoUrl': newPhoto}, SetOptions(merge: true));
              if (coupleId.isNotEmpty) {
                final cSnap = await FirebaseFirestore.instance.doc('couples/$coupleId').get();
                final amA = cSnap.data()?['createdBy'] == myId;
                await FirebaseFirestore.instance.doc('couples/$coupleId').update({
                  amA ? 'displayNameA' : 'displayNameB': newName,
                  amA ? 'photoA' : 'photoB': newPhoto,
                });
              }
              await AuthService().refresh();
            },
            icon: const Icon(Icons.save), label: const Text('Simpan'),
          )),
        ]),
      )),
    );
  }

  Future<DateTime?> _pick(BuildContext context, DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
  }
}

class SliverToBoxHeader extends StatelessWidget {
  final String label;
  const SliverToBoxHeader({super.key, required this.label});
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [Icon(Icons.auto_awesome, size: 16, color: DyKalTheme.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
        ),
      );
}
