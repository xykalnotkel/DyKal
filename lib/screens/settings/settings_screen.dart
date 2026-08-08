import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../config/theme.dart';
import '../../services/theme_controller.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/floating_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
// CATATAN: 'system_ringtone_picker' DIHAPUS — package itu TIDAK ADA di pub.dev (404). Dipake sebelumnya bikin compile error.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifChat = true;
  bool _notifCall = true;
  bool _notifLetter = true;
  bool _notifBirthday = true;
  bool _notifSound = true;
bool _notifVibrate = true;
  List<String> _storyAudioPaths = [];
  String _notifRingtone = 'Default Sistem';
  String _callRingtone = 'Default Sistem';
  final _audioPlayer = AudioPlayer();
  int _bubbleStyle = 0; // FIX: dipake tapi gak pernah dideklarasi -> compile error

@override
  void initState() {
    super.initState();
    _loadAudioPaths();
    _loadBubbleStyle();
  }

Future<void> _loadBubbleStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bubbleStyle = prefs.getInt('bubble_style') ?? 0);
  }

  Future<void> _setBubbleStyle(int style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bubble_style', style);
    setState(() => _bubbleStyle = style);
  }

  Future<void> _loadAudioPaths() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _storyAudioPaths = prefs.getStringList('story_audio_playlist') ?? []);
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
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(children: [
        _sectionHeader('Pusat Notifikasi'),
        _toggle(Icons.chat, 'Notifikasi Chat', _notifChat),
        _toggle(Icons.call, 'Notifikasi Telepon', _notifCall),
        _toggle(Icons.mail, 'Notifikasi Surat', _notifLetter),
        _toggle(Icons.cake, 'Ultah & Anniversary', _notifBirthday),
        const Divider(),
        _sectionHeader('Nada Dering & Suara'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Catatan: pemilih nada dering sistem sedang diperbaiki (package yang dipakai sebelumnya ternyata tidak ada di pub.dev). Untuk sementara pakai nada default sistem.', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
        ),
        _toggle(Icons.volume_up, 'Suara Notifikasi', _notifSound),
        _toggle(Icons.vibration, 'Getaran', _notifVibrate),
        const Divider(),
        _sectionHeader('Izin Overlay (Floating Bubble)'),
        FutureBuilder<bool>(
          future: FloatingService.hasOverlayPermission(),
          builder: (_, snap) => ListTile(
            leading: Icon(Icons.picture_in_picture, color: snap.data == true ? DyKalTheme.primary : Colors.red),
            title: Text(snap.data == true ? 'Izin Overlay: Aktif' : 'Izin Overlay: Belum Aktif', style: const TextStyle(fontSize: 14)),
            subtitle: const Text('Untuk floating chat & video call di atas app lain', style: TextStyle(fontSize: 11)),
            trailing: snap.data == true ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.warning, color: Colors.orange),
            onTap: () => FloatingService.requestOverlayPermission(),
          ),
        ),

        const Divider(),
        _sectionHeader('Izin Notifikasi'),
        _tile(Icons.settings_applications, 'Buka Pengaturan Notifikasi', 'Kelola izin di sistem'),
        const Divider(),
        _sectionHeader('Audio Story Playlist'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Lagu diputar random saat story dibuka. Tersimpan permanen di HP (gak hilang walau ganti akun).', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
        ),
        if (_storyAudioPaths.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Belum ada lagu. Tap + untuk tambah.', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12))))
        else
          ..._storyAudioPaths.asMap().entries.map((e) => ListTile(
            leading: const Icon(Icons.music_note, color: Color(0xFFFF6B8A)),
            title: Text(e.value.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.play_arrow, size: 20), onPressed: () => _previewAudio(e.value)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _removeAudio(e.key)),
            ]),
          )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(onPressed: _addAudio, icon: const Icon(Icons.add), label: const Text('Tambah Lagu dari HP')),
        ),

        const Divider(),
        _sectionHeader('Tampilan'),
        _themeRow(),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('Gaya Bubble Chat', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Expanded(child: _bubbleChip(0, 'Bulat', Icons.circle_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _bubbleChip(1, 'Kotak', Icons.square_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _bubbleChip(2, 'Ekor', Icons.chat_bubble_outline)),
        ])),
        const SizedBox(height: 24),
        FutureBuilder<String>(
          future: () async {
            final info = await PackageInfo.fromPlatform();
            return 'DyKal v' + info.version;
          }(),
          builder: (_, ss) => Text(
            ss.data ?? 'DyKal',
            textAlign: TextAlign.center,
            style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFFF6B8A))),
  );

  Widget _toggle(IconData icon, String title, bool value) {
    return ListTile(
      leading: Icon(icon, color: DyKalTheme.textGrey),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Switch(value: value, onChanged: (v) => setState(() {}), activeColor: DyKalTheme.primary),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, [VoidCallback? onTap]) {
    return ListTile(
      leading: Icon(icon, color: DyKalTheme.textGrey),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap ?? () async {
        final plugin = FlutterLocalNotificationsPlugin();
        final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) await android.requestNotificationsPermission();
      },
    );
  }

  Widget _themeRow() => ListenableBuilder(
    listenable: ThemeController.instance,
    builder: (_, __) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _themeChip('Sistem', ThemeMode.system),
        const SizedBox(width: 8),
        _themeChip('Terang', ThemeMode.light),
        const SizedBox(width: 8),
        _themeChip('Gelap', ThemeMode.dark),
      ]),
    ),
  );

Widget _bubbleChip(int style, String label, IconData icon) {
    final active = _bubbleStyle == style;
    return GestureDetector(
      onTap: () => _setBubbleStyle(style),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? DyKalTheme.primary : DyKalTheme.borderSoft, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [Icon(icon, size: 20, color: active ? Colors.white : DyKalTheme.textGrey), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? Colors.white : DyKalTheme.textGrey, fontSize: 11, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _themeChip(String label, ThemeMode mode) {
    final active = ThemeController.instance.mode == mode;
    return GestureDetector(
      onTap: () => ThemeController.instance.set(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? DyKalTheme.primary : DyKalTheme.borderSoft, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : DyKalTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
