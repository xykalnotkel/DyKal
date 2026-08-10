import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart'; // FIX profile: crop foto bulat
import '../../widgets/gallery_picker.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/birthday_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/theme_controller.dart';
import '../settings/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return StreamBuilder<DocumentSnapshot>(
      stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final nameA = (d?['displayNameA'] as String?) ?? '';
        final nameB = (d?['displayNameB'] as String?) ?? '';
        final bA = (d?['birthdayA'] as Timestamp?)?.toDate();
        final bB = (d?['birthdayB'] as Timestamp?)?.toDate();
        final ann = (d?['anniversary'] as Timestamp?)?.toDate();
        return CustomScrollView(slivers: [
          SliverAppBar(backgroundColor: Colors.transparent, elevation: 0, floating: true, title: const Text("Profil & Pengaturan")),
          SliverToBoxAdapter(child: _coupleCard()),
          SliverToBoxHeader(label: "Tanggal Penting"),
          SliverToBoxAdapter(child: _dateTile(context, Icons.favorite, "Anniversary", ann, () async {
            final picked = await _pick(context, ann);
            if (picked != null) {
              await FirebaseFirestore.instance.doc('couples/$coupleId').update({'anniversary': Timestamp.fromDate(picked)});
              await BirthdayService().scheduleAnniversary(picked);
            }
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
              onPressed: () async { await BirthdayService().scheduleBirthdays(birthdayA: bA, birthdayB: bB, nameA: nameA, nameB: nameB); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifikasi ulang tahun dijadwalkan'))); },
              icon: const Icon(Icons.notifications_active, size: 16), label: const Text('Jadwalkan Notif Ulang Tahun'),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxHeader(label: "Tampilan"),
          SliverToBoxAdapter(child: _themeSelector()),
          SliverToBoxHeader(label: "Akun"),
          SliverToBoxAdapter(child: _editProfileTile(context)),
          SliverToBoxAdapter(child: _changePasswordTile(context)),
          SliverToBoxAdapter(child: _settingsTile(context)),
          SliverToBoxAdapter(child: _account(context, nameA)),
          SliverToBoxAdapter(child: _versionFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]);
      },
    );
  }

  Widget _coupleCard() {
    final myId = AuthService().myId;
    final partnerId = AuthService().partnerId ?? '';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), image: const DecorationImage(image: AssetImage('assets/illustrations/card_bg.webp'), fit: BoxFit.cover)),
      child: Row(children: [
        Expanded(child: _memberCol(myId, '')),
        const Icon(Icons.favorite, color: Colors.white, size: 28),
        Expanded(child: _memberCol(partnerId, '')),
      ]),
    );
  }

  Widget _memberCol(String uid, String fallback) {
    if (uid.isEmpty) {
      return Column(children: [
        CircleAvatar(radius: 34, backgroundColor: Colors.white.withValues(alpha: 0.25), child: Text(fallback.isNotEmpty ? fallback[0] : '?', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Text(fallback, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]);
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final name = (d?['displayName'] as String?) ?? fallback;
        final photo = d?['photoUrl'] as String?;
        return Column(children: [
          CircleAvatar(radius: 34, backgroundColor: Colors.white.withValues(alpha: 0.25), backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null, child: photo == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800)) : null),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ]);
      },
    );
  }

  Widget _dateTile(BuildContext context, IconData icon, String label, DateTime? value, VoidCallback onTap) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: DyKalTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: DyKalTheme.primary, size: 20)),
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
          ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), tileColor: DyKalTheme.cardOf(context),
            leading: CircleAvatar(backgroundColor: DyKalTheme.primary.withValues(alpha: 0.15), child: Icon(Icons.person, color: DyKalTheme.primary)),
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
          color: DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: DyKalTheme.primary.withValues(alpha: 0.15), child: Icon(Icons.edit, color: DyKalTheme.primary)),
            title: const Text('Edit Nama & Foto', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Ubah profil kamu (real-time)', style: TextStyle(fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: DyKalTheme.textGrey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => _editProfile(context),
          ),
        ),
      );

  Widget _settingsTile(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: DyKalTheme.primary.withValues(alpha: 0.15), child: Icon(Icons.tune, color: DyKalTheme.primary)),
            title: const Text('Pengaturan Lanjutan', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Notifikasi, overlay, bubble, story audio', style: TextStyle(fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: DyKalTheme.textGrey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ),
      );

  Widget _versionFooter() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FutureBuilder<String>(
          future: () async {
            final info = await PackageInfo.fromPlatform();
            return 'DyKal v${info.version}';
          }(),
          builder: (_, s) => Text(
            s.data ?? 'DyKal',
            textAlign: TextAlign.center,
            style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12),
          ),
        ),
      );

  Future<void> _editProfile(BuildContext context) async {
    final auth = AuthService();
    final coupleId = auth.coupleId ?? '';
    final myId = auth.myId;
    final nameCtl = TextEditingController(text: auth.myName);
    final statusCtl = TextEditingController(text: auth.myStatus);
    String? photoUrl = auth.myPhotoUrl;
    File? picked;
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (s) => Scaffold(
            appBar: AppBar(
        title: const Text('Edit Profil'),
        leading: IconButton(onPressed: () => Navigator.pop(s), icon: const Icon(Icons.close)),
      ),
      body: SafeArea(child: SingleChildScrollView(child: StatefulBuilder(builder: (s, setS) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(s).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final pickedFile = await Navigator.push<File>(s, MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: false)));
              if (pickedFile == null) return;
              // FIX profile: crop bentuk bulat sebelum preview
              final cropped = await ImageCropper().cropImage(
                sourcePath: pickedFile.path,
                uiSettings: [
                  AndroidUiSettings(toolbarTitle: 'Atur Foto', cropStyle: CropStyle.circle, lockAspectRatio: true, toolbarColor: DyKalTheme.primary, toolbarWidgetColor: Colors.white),
                  IOSUiSettings(title: 'Atur Foto', cropStyle: CropStyle.circle),
                ],
              );
              if (cropped != null) setS(() => picked = File(cropped.path));
            },
            child: CircleAvatar(radius: 42, backgroundColor: DyKalTheme.primary.withValues(alpha: 0.15), backgroundImage: picked != null ? FileImage(picked!) as ImageProvider : (photoUrl != null ? CachedNetworkImageProvider(photoUrl) as ImageProvider : null), child: (picked == null && photoUrl == null) ? Icon(Icons.person, size: 40, color: DyKalTheme.primary) : null),
          ),
          const SizedBox(height: 8),
          Text('Ketuk foto untuk ganti', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtl,
            style: TextStyle(color: DyKalTheme.textPrimaryOf(s)),
            decoration: InputDecoration(
              hintText: 'Nama panggilan',
              filled: true,
              fillColor: Theme.of(s).brightness == Brightness.dark ? DyKalTheme.surfaceDark : const Color(0xFFFFF8F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: statusCtl,
            maxLength: 80,
            style: TextStyle(color: DyKalTheme.textPrimaryOf(s)),
            decoration: InputDecoration(
              hintText: 'Status (mis. "Selalu bahagia")',
              filled: true,
              fillColor: Theme.of(s).brightness == Brightness.dark ? DyKalTheme.surfaceDark : const Color(0xFFFFF8F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () async {
              final newName = nameCtl.text.trim();
              final newStatus = statusCtl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(s);
              String? newPhoto = photoUrl;
              if (picked != null) {
                try { newPhoto = await CloudinaryService().uploadAvatar(picked!); } catch (_) {}
              }
              // FIX: TULIS users doc DULU (nama WAJIB kesimpen walau foto gagal)
              try {
                await FirebaseFirestore.instance.doc('users/$myId').set({'displayName': newName, 'photoUrl': newPhoto, 'status': newStatus}, SetOptions(merge: true));
              } catch (e) {
                if (s.mounted) ScaffoldMessenger.of(s).showSnackBar(SnackBar(content: Text('Gagal simpan profil: $e')));
              }
              if (coupleId.isNotEmpty) {
                try {
                  final cSnap = await FirebaseFirestore.instance.doc('couples/$coupleId').get();
                  final amA = cSnap.data()?['createdBy'] == myId;
                  await FirebaseFirestore.instance.doc('couples/$coupleId').update({
                    amA ? 'displayNameA' : 'displayNameB': newName,
                    amA ? 'photoA' : 'photoB': newPhoto,
                  });
                } catch (_) {}
              }
              try { await FirebaseAuth.instance.currentUser?.updateDisplayName(newName); } catch (_) {}
              await AuthService().refresh();
            },
            icon: const Icon(Icons.save), label: const Text('Simpan'),
          )),
        ]),
      ))))),
    ));
  }

  Widget _changePasswordTile(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: DyKalTheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.lock_outline, color: DyKalTheme.primary),
            ),
            title: const Text('Ganti Kata Sandi', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Perbarui password akun', style: TextStyle(fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: DyKalTheme.textGrey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => _changePassword(context),
          ),
        ),
      );

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    if (email.isEmpty || user == null) return;

    final curCtl = TextEditingController();
    final newCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Ganti Kata Sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: curCtl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Kata sandi saat ini', filled: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Kata sandi baru (min. 6 karakter)', filled: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final cur = curCtl.text.trim();
    final newPwd = newCtl.text.trim();
    if (cur.isEmpty || newPwd.length < 6) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi kata sandi dengan benar (baru min. 6 karakter)')),
        );
      }
      return;
    }
    try {
      final cred = EmailAuthProvider.credential(email: email, password: cur);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPwd);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kata sandi berhasil diubah')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: pastikan kata sandi saat ini benar ($e)')),
        );
      }
    }
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
