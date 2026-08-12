import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/bubble_style.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../services/theme_controller.dart';
import '../../services/floating_service.dart';
import '../../services/ringtone_service.dart';
import '../../services/cloudinary_service.dart';
import 'package:dio/dio.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notifikasi
  bool _notifChat = true;
  bool _notifCall = true;
  bool _notifLetter = true;
  bool _notifBirthday = true;
  bool _notifSound = true;
  bool _notifVibrate = true;
  String _notifRingtone = 'Default DyKal';
  String _callRingtone = 'Default DyKal';

  // Audio Player & Story
  final _audioPlayer = AudioPlayer();
  List<String> _storyAudioPaths = [];
  int _bubbleStyle = 0;
  int _mediaVisibility = 0;
  String _cacheSize = '0 MB';
  bool _bubbleEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAllPreferences();
    _calculateCacheSize();
  }

  Future<void> _loadAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifSound = prefs.getBool('notif_sound') ?? true;
      _notifVibrate = prefs.getBool('notif_vibrate') ?? true;
      _notifRingtone = prefs.getString('notif_ringtone_title') ?? 'Default DyKal';
      _callRingtone = prefs.getString('call_ringtone_title') ?? 'Default DyKal';
      _bubbleStyle = prefs.getInt('bubble_style') ?? 0;
      _mediaVisibility = prefs.getInt('media_visibility_pref') ?? 0;
      _storyAudioPaths = prefs.getStringList('story_audio_playlist') ?? [];
      _bubbleEnabled = prefs.getBool('floating_bubble_enabled') ?? false;
    });

    // Auto-tampilkan bubble saat aplikasi dibuka jika toggle aktif dan izin ada.
    if (_bubbleEnabled) {
      final ok = await FloatingService.hasOverlayPermission();
      if (ok) await FloatingService.showChatBubble();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.doc('users/$uid').get();
      final p = (snap.data()?['notifPrefs'] as Map<String, dynamic>?) ?? {};
      if (mounted) {
        setState(() {
          _notifChat = p['chat'] ?? true;
          _notifCall = p['call'] ?? true;
          _notifLetter = p['letter'] ?? true;
          _notifBirthday = p['birthday'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveNotifPref(String key, bool v) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.doc('users/$uid').set({
        'notifPrefs': {key: v}
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveLocalPref(String key, dynamic v) async {
    final prefs = await SharedPreferences.getInstance();
    if (v is bool) await prefs.setBool(key, v);
    if (v is String) await prefs.setString(key, v);
    if (v is int) await prefs.setInt(key, v);
  }

  /// Aktif/nonaktifkan floating chat bubble (chat head).
  Future<void> _toggleFloatingBubble(bool enable) async {
    if (enable) {
      final ok = await FloatingService.hasOverlayPermission();
      if (!ok) {
        await FloatingService.requestOverlayPermission();
        await _saveLocalPref('floating_bubble_enabled', false);
        if (mounted) {
          setState(() => _bubbleEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izinkan izin overlay di pengaturan sistem, lalu aktifkan kembali'),
            ),
          );
        }
        return;
      }
      await FloatingService.showChatBubble();
    } else {
      await FloatingService.hideBubble();
    }
    await _saveLocalPref('floating_bubble_enabled', enable);
    if (mounted) setState(() => _bubbleEnabled = enable);
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (await tempDir.exists()) {
        await for (final file in tempDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            final stat = await file.stat();
            totalBytes += stat.size;
          }
        }
      }
      if (mounted) {
        setState(() {
          _cacheSize = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        });
      }
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }
      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas cache aplikasi berhasil dibersihkan')),
        );
      }
    } catch (_) {}
  }

  Future<void> _addAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final newPaths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
    setState(() => _storyAudioPaths.addAll(newPaths));
    await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
  }

  Future<void> _removeAudio(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _storyAudioPaths.removeAt(index));
    await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
  }

  /// Tambah lagu dari VIDEO: video diupload ke Cloudinary lalu diambil
  /// audio-nya (MP3) — TANPA backend/FFmpeg, cukup ubah ekstensi URL.
  /// FIX (laporan owner "gada status upload/loading"): dialog progres 2 fase
  /// (upload -> unduh hasil) dengan persen, jadi jelas prosesnya jalan.
  Future<void> _addAudioFromVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty || result.files.single.path == null) return;
    if (!mounted) return;

    final progress = ValueNotifier<double>(0.0);
    final phase = ValueNotifier<String>('Mengupload video...');
    bool dialogOpen = true;
    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Menyiapkan audio story'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: p == 0 ? null : p),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: phase,
                  builder: (_, ph, __) => Text('$ph ${(p * 100).clamp(0, 100).toInt()}%'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final audioUrl = await CloudinaryService().uploadVideoForAudio(
        File(result.files.single.path!),
        onProgress: (p) {
          progress.value = p * 0.7; // fase upload = 70% pertama
        },
      );
      if (audioUrl == null) throw Exception('konversi gagal');
      phase.value = 'Mengunduh MP3...';
      progress.value = 0.7;

      // Unduh MP3 ke folder lokal agar bisa diputar offline
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await Dio().download(audioUrl, savePath, onReceiveProgress: (r, t) {
        if (t > 0) progress.value = 0.7 + (r / t) * 0.3;
      });

      final prefs = await SharedPreferences.getInstance();
      setState(() => _storyAudioPaths.add(savePath));
      await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
      closeDialog();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio dari video ditambahkan')));
    } catch (e) {
      closeDialog();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _previewAudio(String path) async {
    try {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DyKalTheme.backgroundDark
          : DyKalTheme.background,
      appBar: AppBar(
        title: const Text('Pengaturan Lanjutan', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 1. NOTIFIKASI & DERAG
          _sectionCard(
            title: 'Notifikasi & Dering',
            icon: Icons.notifications_active_outlined,
            children: [
              _tile(
                Icons.music_note_outlined,
                'Nada Notifikasi',
                _notifRingtone,
                () => _selectRingtoneDialog(
                  type: 2,
                  prefKey: 'notif_ringtone_title',
                  currentVal: _notifRingtone,
                  onSelect: (v) => setState(() => _notifRingtone = v),
                ),
              ),
              _tile(
                Icons.phone_in_talk_outlined,
                'Nada Panggilan',
                _callRingtone,
                () => _selectRingtoneDialog(
                  type: 1,
                  prefKey: 'call_ringtone_title',
                  currentVal: _callRingtone,
                  onSelect: (v) => setState(() => _callRingtone = v),
                ),
              ),
              _toggle(Icons.volume_up_outlined, 'Suara Notifikasi', _notifSound, (v) {
                setState(() => _notifSound = v);
                _saveLocalPref('notif_sound', v);
              }),
              _toggle(Icons.vibration, 'Getaran', _notifVibrate, (v) {
                setState(() => _notifVibrate = v);
                _saveLocalPref('notif_vibrate', v);
              }),
              const Divider(height: 1),
              _toggle(Icons.chat_bubble_outline, 'Notifikasi Chat Masuk', _notifChat, (v) {
                setState(() => _notifChat = v);
                _saveNotifPref('chat', v);
              }),
              _toggle(Icons.videocam_outlined, 'Notifikasi Panggilan', _notifCall, (v) {
                setState(() => _notifCall = v);
                _saveNotifPref('call', v);
              }),
              _toggle(Icons.mail_outline, 'Notifikasi Surat Cinta', _notifLetter, (v) {
                setState(() => _notifLetter = v);
                _saveNotifPref('letter', v);
              }),
              _toggle(Icons.cake_outlined, 'Pengingat Ultah & Anniversary', _notifBirthday, (v) {
                setState(() => _notifBirthday = v);
                _saveNotifPref('birthday', v);
              }),
              _tile(
                Icons.settings_suggest_outlined,
                'Izin Notifikasi Sistem',
                'Buka pengaturan Android',
                () => openAppSettings(),
              ),
            ],
          ),

          // 2. TAMPILAN & GAYA ANTARMUKA
          _sectionCard(
            title: 'Tampilan & Gaya Antarmuka',
            icon: Icons.palette_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: const Text('Mode Tema', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              _themeRow(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: const Text('Gaya Desain Antarmuka', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              _uiStyleRow(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: const Text('Bentuk Bubble Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: _bubbleChip(0, 'Bulat', Icons.circle_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _bubbleChip(1, 'Kotak', Icons.square_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _bubbleChip(2, 'Ekor', Icons.chat_bubble_outline)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),

          // 3. PRIVASI & KEAMANAN
          _sectionCard(
            title: 'Privasi & Keamanan',
            icon: Icons.security_outlined,
            children: [
              _infoTile(
                Icons.lock_outline,
                'Enkripsi Data Media',
                'AES-256-GCM Hardware Cipher (.webp.crypt15)',
              ),
              FutureBuilder<bool>(
                future: FloatingService.hasOverlayPermission(),
                builder: (_, snap) => ListTile(
                  leading: Icon(
                    Icons.picture_in_picture_alt_outlined,
                    color: snap.data == true ? DyKalTheme.online : Colors.orange,
                  ),
                  title: const Text('Izin Floating Bubble / Overlay', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    snap.data == true ? 'Aktif (dapat melayang di atas aplikasi lain)' : 'Belum aktif (ketuk untuk izin)',
                    style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context)),
                  ),
                  trailing: Icon(
                    snap.data == true ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: snap.data == true ? DyKalTheme.online : Colors.orange,
                  ),
                  onTap: () => FloatingService.requestOverlayPermission(),
                ),
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.bubble_chart,
                  color: _bubbleEnabled ? DyKalTheme.primary : DyKalTheme.textGrey,
                ),
                title: const Text('Floating Bubble (Chat Head)', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _bubbleEnabled
                      ? 'Bubble melayang di atas aplikasi lain'
                      : 'Tampilkan bubble chat saat keluar aplikasi',
                  style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context)),
                ),
                value: _bubbleEnabled,
                activeThumbColor: DyKalTheme.primary,
                onChanged: _toggleFloatingBubble,
              ),
              _tile(
                Icons.visibility_outlined,
                'Visibilitas Media di Galeri',
                _mediaVisibility == 0 ? 'Semua Disimpan' : (_mediaVisibility == 1 ? 'Hanya Foto' : 'Manual (Tidak)'),
                () => _selectMediaVisibilityDialog(),
              ),
            ],
          ),

          // 4. PENYIMPANAN & DATA
          _sectionCard(
            title: 'Penyimpanan & Data',
            icon: Icons.storage_outlined,
            children: [
              _infoTile(
                Icons.folder_outlined,
                'Lokasi Scoped Media',
                'Android/media/com.dykal.app/Dykal/Media/',
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined, color: Colors.redAccent),
                title: const Text('Bersihkan Berkas Sementara', style: TextStyle(fontSize: 14)),
                subtitle: Text('Ukuran cache saat ini: $_cacheSize', style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context))),
                trailing: TextButton(
                  onPressed: _clearCache,
                  child: const Text('Bersihkan', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // 5. AKSESIBILITAS & AUDIO CERITA
          _sectionCard(
            title: 'Aksesibilitas & Audio Cerita',
            icon: Icons.graphic_eq_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'Playlist Musik Story Album (diputar acak saat melihat cerita):',
                  style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context)),
                ),
              ),
              if (_storyAudioPaths.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('Belum ada berkas lagu.', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12)),
                  ),
                )
              else
                ..._storyAudioPaths.asMap().entries.map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.music_note, color: DyKalTheme.primary),
                      title: Text(e.value.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.play_arrow, size: 18), onPressed: () => _previewAudio(e.value)),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _removeAudio(e.key)),
                        ],
                      ),
                    )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _addAudio,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Musik dari HP'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: _addAudioFromVideo,
                  icon: const Icon(Icons.video_library, size: 18),
                  label: const Text('Tambah dari Video (jadi MP3)'),
                ),
              ),
            ],
          ),

          // 6. TENTANG & INFORMASI APLIKASI
          _sectionCard(
            title: 'Tentang & Informasi Aplikasi',
            icon: Icons.info_outline,
            children: [
              FutureBuilder<String>(
                future: () async {
                  final info = await PackageInfo.fromPlatform();
                  return 'DyKal v${info.version} (Build ${info.buildNumber})';
                }(),
                builder: (_, s) => _infoTile(
                  Icons.verified_outlined,
                  'Versi Aplikasi',
                  s.data ?? 'DyKal v1.0.17',
                ),
              ),
              _infoTile(
                Icons.cloud_done_outlined,
                'Infrastruktur Realtime',
                'Google Firestore & Cloudflare Worker',
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: DyKalTheme.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DyKalTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(icon, color: DyKalTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: DyKalTheme.primary),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _toggle(IconData icon, String title, bool value, ValueChanged<bool>? onChanged) {
    return ListTile(
      leading: Icon(icon, color: DyKalTheme.textSecondaryOf(context), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: DyKalTheme.primary,
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: DyKalTheme.textSecondaryOf(context), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context))),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: DyKalTheme.textSecondaryOf(context), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context))),
    );
  }

  Widget _themeRow() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final mode = ThemeController.instance.mode;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto, size: 16)),
              ButtonSegment(value: ThemeMode.light, label: Text('Terang'), icon: Icon(Icons.light_mode, size: 16)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Gelap'), icon: Icon(Icons.dark_mode, size: 16)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ThemeController.instance.set(s.first),
          ),
        );
      },
    );
  }

  Widget _uiStyleRow() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final currentStyle = ThemeController.instance.style;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<AppUiStyle>(
            segments: const [
              ButtonSegment(value: AppUiStyle.rounded, label: Text('Rounded'), icon: Icon(Icons.rounded_corner, size: 16)),
              ButtonSegment(value: AppUiStyle.ios, label: Text('iOS Style'), icon: Icon(Icons.phone_iphone, size: 16)),
              ButtonSegment(value: AppUiStyle.sharp, label: Text('Sharp'), icon: Icon(Icons.crop_square, size: 16)),
            ],
            selected: {currentStyle},
            onSelectionChanged: (s) => ThemeController.instance.setStyle(s.first),
          ),
        );
      },
    );
  }

  Widget _bubbleChip(int style, String label, IconData icon) {
    final active = _bubbleStyle == style;
    return GestureDetector(
      onTap: () {
        setState(() => _bubbleStyle = style);
        BubbleStyle.instance.set(style); // sinkron ke bubble (bukan pajangan lagi)
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? DyKalTheme.primary : DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? DyKalTheme.primary : DyKalTheme.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : DyKalTheme.textSecondaryOf(context)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : DyKalTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectRingtoneDialog({
    required int type,
    required String prefKey,
    required String currentVal,
    required ValueChanged<String> onSelect,
  }) async {
    final systemList = await RingtoneService.getRingtones(type: type);
    if (!mounted) return;

    final options = [
      {'title': 'Default DyKal', 'uri': 'asset:default'},
      ...systemList,
    ];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Nada', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, i) {
              final item = options[i];
              final title = (item['title'] as String?) ?? 'Nada';
              final isSelected = title == currentVal;

              return ListTile(
                dense: true,
                title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                trailing: isSelected ? const Icon(Icons.check, color: DyKalTheme.primary, size: 18) : null,
                onTap: () async {
                  await _saveLocalPref(prefKey, title);
                  onSelect(title);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _selectMediaVisibilityDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Visibilitas Media di Galeri', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              value: 0,
              groupValue: _mediaVisibility,
              title: const Text('Semua Media (Foto & Video)', style: TextStyle(fontSize: 13)),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _mediaVisibility = v);
                  _saveLocalPref('media_visibility_pref', v);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<int>(
              value: 1,
              groupValue: _mediaVisibility,
              title: const Text('Hanya Foto', style: TextStyle(fontSize: 13)),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _mediaVisibility = v);
                  _saveLocalPref('media_visibility_pref', v);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _mediaVisibility,
              title: const Text('Manual (Tidak simpan ke galeri)', style: TextStyle(fontSize: 13)),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _mediaVisibility = v);
                  _saveLocalPref('media_visibility_pref', v);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
