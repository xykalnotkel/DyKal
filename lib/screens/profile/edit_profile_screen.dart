import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/gallery_picker.dart';
import '../../widgets/photo_shape.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtl = TextEditingController();
  final _statusCtl = TextEditingController();
  PhotoShape _avatarShape = PhotoShape.bulat;
  String? _photoUrl;
  File? _pickedFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _nameCtl.text = auth.myName;
    _statusCtl.text = auth.myStatus;
    _avatarShape = shapeFromName(auth.myAvatarShape);
    _photoUrl = auth.myPhotoUrl;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _statusCtl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: false)),
    );
    if (file == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur Foto Avatar',
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          toolbarColor: DyKalTheme.primary,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: 'Atur Foto Avatar', cropStyle: CropStyle.circle),
      ],
    );
    if (cropped != null && mounted) {
      setState(() => _pickedFile = File(cropped.path));
    }
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama minimal 2 karakter')),
      );
      return;
    }
    setState(() => _saving = true);
    final auth = AuthService();
    final myId = auth.myId;
    final coupleId = auth.coupleId ?? '';

    String? url = _photoUrl;
    if (_pickedFile != null) {
      url = await CloudinaryService().uploadImage(_pickedFile!, folder: 'dykal/avatars');
    }

    final fields = <String, dynamic>{
      'displayName': name,
      'status': _statusCtl.text.trim(),
      'avatarShape': _avatarShape.name,
    };
    if (url != null) fields['photoUrl'] = url;

    try {
      await FirebaseFirestore.instance.doc('users/$myId').set(fields, SetOptions(merge: true));
      if (coupleId.isNotEmpty) {
        final cDoc = await FirebaseFirestore.instance.doc('couples/$coupleId').get();
        final members = List<String>.from(cDoc.data()?['members'] ?? []);
        if (members.isNotEmpty) {
          final iAmA = members.first == myId;
          final cf = <String, dynamic>{
            iAmA ? 'displayNameA' : 'displayNameB': name,
          };
          if (url != null) cf[iAmA ? 'photoA' : 'photoB'] = url;
          await FirebaseFirestore.instance.doc('couples/$coupleId').set(cf, SetOptions(merge: true));
        }
      }
      await auth.refresh();
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? DyKalTheme.backgroundDark : DyKalTheme.background,
      appBar: AppBar(
        title: const Text('Edit Profil Kamu', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Avatar dengan badge kamera ala WA
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipPath(
                        clipper: photoShapeClipper(_avatarShape),
                        child: Container(
                          width: 110,
                          height: 110,
                          color: DyKalTheme.primary.withValues(alpha: 0.15),
                          child: _pickedFile != null
                              ? Image.file(_pickedFile!, fit: BoxFit.cover)
                              : (_photoUrl != null && _photoUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: _photoUrl!, fit: BoxFit.cover)
                                  : const Icon(Icons.person, size: 56, color: DyKalTheme.primary)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: DyKalTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pilihan bentuk avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final shape in [PhotoShape.bulat, PhotoShape.love, PhotoShape.bunga, PhotoShape.abstrak])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(shape.label),
                        selected: _avatarShape == shape,
                        selectedColor: DyKalTheme.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _avatarShape = shape),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              // Field Nama
              Align(
                alignment: Alignment.centerLeft,
                child: Text('NAMA PANGGILAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DyKalTheme.primary)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtl,
                style: TextStyle(color: DyKalTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: 'Nama panggilan kamu',
                  prefixIcon: const Icon(Icons.person_outline, color: DyKalTheme.primary),
                  filled: true,
                  fillColor: DyKalTheme.cardOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Field Status
              Align(
                alignment: Alignment.centerLeft,
                child: Text('STATUS (BIO)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DyKalTheme.primary)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _statusCtl,
                style: TextStyle(color: DyKalTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: 'Status singkat atau motto',
                  prefixIcon: const Icon(Icons.favorite_outline, color: DyKalTheme.primary),
                  filled: true,
                  fillColor: DyKalTheme.cardOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Email (info)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DyKalTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DyKalTheme.borderOf(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, color: DyKalTheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email Akun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(AuthService().currentUser?.email ?? 'Tanpa email', style: TextStyle(fontSize: 13, color: DyKalTheme.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
