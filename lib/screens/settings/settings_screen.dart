import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/bubble_style.dart';
import '../../services/e2e_service.dart';
import '../../services/wallpaper_settings.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/font_scale.dart';
import '../../services/music_catalog.dart';
import '../../services/story_mood.dart';
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
  Map<String, StoryMood> _storyMoods = {};
  int _bubbleStyle = 0;
  int _mediaVisibility = 0;
  // Statistik penyimpanan per kategori (label -> bytes) — UI bar bersegmen.
  Map<String, int> _storage = {};
  int _storageTotal = 0;
  bool _bubbleEnabled = false;

  // BATCH I: fitur pengaturan baru
  bool _activityShare = false; // laporkan app yang sedang dibuka (opt-in)
  bool _dataSaver = false;     // kompresi upload lebih agresif
  double _fontScale = 1.0;
  static const _chActivity = MethodChannel('dykal/activity');

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
      _activityShare = prefs.getBool('activity_share_enabled') ?? false;
      _dataSaver = prefs.getBool('data_saver') ?? false;
      _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    });
    _storyMoods = await StoryMoodStore.load();
    // Pastikan service native konsisten dengan pref (restart service bila ON).
    if (_activityShare) {
      try { await _chActivity.invokeMethod('start'); } catch (_) {}
    }
    if (mounted) setState(() {});

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

  /// Hitung ukuran per kategori: cache, foto, video, audio/VN, stiker,
  /// wallpaper. Sumber: tempDir + struktur MediaSaver + folder wallpaper.
  Future<void> _calculateCacheSize() async {
    try {
      final m = <String, int>{};

      int? tempBytes;
      Future<int> dirSize(String path) async {
        var total = 0;
        final d = Directory(path);
        if (!await d.exists()) return 0;
        await for (final e in d.list(recursive: true, followLinks: false)) {
          if (e is File) total += (await e.stat()).size;
        }
        return total;
      }

      final tempDir = await getTemporaryDirectory();
      tempBytes = await dirSize(tempDir.path);
      m['Cache sementara'] = tempBytes;

      // BATCH H (owner: "bukan cuma static cache, tapi total yang dipakai
      // aplikasi"): tambah cache internal app (image cache Flutter, dll) ke
      // statistik & tombol bersihkan.
      try {
        final cacheDir = await getApplicationCacheDirectory();
        m['Cache aplikasi'] = await dirSize(cacheDir.path);
      } catch (_) {}

      const root = '/storage/emulated/0/Android/media/com.dykal.app/Dykal/Media';
      m['Foto & Gambar'] = await dirSize('$root/Dykal Images');
      m['Video'] = await dirSize('$root/Dykal Video');
      m['Audio & Voice Note'] = await dirSize('$root/Dykal Audio');
      m['Stiker'] = await dirSize('$root/Dykal Stickers');

      final docs = await getApplicationDocumentsDirectory();
      m['Wallpaper kustom'] = await dirSize('${docs.path}/wallpapers');

      final total = m.values.fold<int>(0, (a, b) => a + b);
      if (mounted) {
        setState(() {
          _storage = m;
          _storageTotal = total;
        });
      }
    } catch (_) {}
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    final kb = b / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }
      // BATCH H: cache internal aplikasi juga ikut dibersihkan (image cache
      // flutter engine, thumbnail, dsb) — bukan cuma folder temp.
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          await cacheDir.create();
        }
      } catch (_) {}
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
    setState(() {
      _storyAudioPaths.addAll(newPaths);
      // BATCH I: tebak suasana dari nama file (bisa diubah lewat chip).
      for (final p in newPaths) {
        _storyMoods[p] = StoryMoodAnalyzer.guessFromName(p);
      }
    });
    await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
    await StoryMoodStore.save(_storyMoods);
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
      setState(() {
        _storyAudioPaths.add(savePath);
        _storyMoods[savePath] = StoryMoodAnalyzer.guessFromName(savePath);
      });
      await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
      await StoryMoodStore.save(_storyMoods);
      closeDialog();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio dari video ditambahkan')));
    } catch (e) {
      closeDialog();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  // BATCH H (owner: "audio playlist tes suaranya masih gada pause"):
  // tombol jadi TOGGLE play/pause; ikon berubah mengikuti trek yang bunyi.
  String? _playingAudioPath;

  Future<void> _previewAudio(String path) async {
    try {
      if (_playingAudioPath == path && _audioPlayer.playing) {
        await _audioPlayer.pause();
      } else if (_playingAudioPath == path) {
        await _audioPlayer.play();
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(path);
        await _audioPlayer.play();
      }
      if (mounted) setState(() => _playingAudioPath = path);
      _audioPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed).then((_) {
        if (mounted) setState(() => _playingAudioPath = null);
      }).catchError((_) {});
    } catch (_) {}
  }

  // ================= BATCH I — metode fitur baru =================

  /// Instruksi mulai ulang (per aturan owner): perubahan tampilan besar
  /// menyarankan restart agar seluruh widget lama ikut gaya baru.
  void _restartHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Sebagian berlaku langsung — mulai ulang aplikasi agar konsisten penuh.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Tutup App',
        onPressed: () => SystemNavigator.pop(),
      ),
    ));
  }

  Future<void> _setFontScale(double v) async {
    setState(() => _fontScale = v);
    await FontScale.set(v);
    _restartHint();
  }

  /// Toggle Bagikan Aktivitas (opt-in). Butuh izin "Penggunaan akses"
  /// (App-Ops) yang hanya bisa diberikan di pengaturan Android.
  Future<void> _toggleActivityShare(bool v) async {
    if (!v) {
      try { await _chActivity.invokeMethod('stop'); } catch (_) {}
      setState(() => _activityShare = false);
      await _saveLocalPref('activity_share_enabled', false);
      return;
    }
    Future<bool> hasPerm() async {
      try { return await _chActivity.invokeMethod('hasUsagePermission') == true; } catch (_) { return false; }
    }
    if (!await hasPerm()) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izin Penggunaan Akses'),
          content: const Text(
              'DyKal perlu izin "Penggunaan akses" untuk tahu aplikasi apa yang sedang dibuka (mis. "Lagi buka TikTok").\n\n'
              'Langkah: tekan Buka Pengaturan -> cari DyKal -> aktifkan "Izinkan akses penggunaan" -> kembali ke sini. '
              'Fitur ini hanya membagi NAMA aplikasi (bukan isi layar) dan bisa dimatikan kapan saja.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nanti')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try { await _chActivity.invokeMethod('openUsageSettings'); } catch (_) {}
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
      // Tunggu user kembali & mengaktifkan izin (poll maksimal ~40 detik).
      var granted = false;
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        if (await hasPerm()) { granted = true; break; }
      }
      if (!granted) return;
    }
    try { await _chActivity.invokeMethod('start'); } catch (_) {}
    setState(() => _activityShare = true);
    await _saveLocalPref('activity_share_enabled', true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aktivitas perangkat kini dibagikan ke pasangan')));
    }
  }

  /// Ubah kata sandi: re-auth email+sandi lama -> updatePassword.
  Future<void> _changePasswordDialog() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    String? err;
    var busy = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Ubah Kata Sandi', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldC,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Sandi saat ini'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newC,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Sandi baru', helperText: 'Minimal 6 karakter'),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (newC.text.length < 6) {
                        ss(() => err = 'Sandi baru minimal 6 karakter');
                        return;
                      }
                      ss(() { busy = true; err = null; });
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        if (user == null || email == null) throw 'Sesi tidak valid, login ulang dulu';
                        final cred = EmailAuthProvider.credential(email: email, password: oldC.text);
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(newC.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kata sandi berhasil diganti')));
                        }
                      } on FirebaseAuthException catch (e) {
                        ss(() {
                          busy = false;
                          err = e.code == 'wrong-password' || e.code == 'invalid-credential'
                              ? 'Sandi lama salah'
                              : (e.code == 'weak-password' ? 'Sandi baru terlalu lemah' : 'Gagal: ${e.code}');
                        });
                      } catch (e) {
                        ss(() { busy = false; err = '$e'; });
                      }
                    },
              child: Text(busy ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pilih suasana lagu (dipakai story player agar musik senada foto).
  Future<void> _pickMood(int index) async {
    final path = _storyAudioPaths[index];
    final picked = await showModalBottomSheet<StoryMood>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Suasana lagu ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: StoryMood.values
                    .map((m) => ActionChip(
                          label: Text(StoryMoodAnalyzer.labels[m]!),
                          onPressed: () => Navigator.pop(ctx, m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                'Story memutar lagu yang senada dengan suasana foto (terang+cerah = Ceria, dst).',
                style: TextStyle(fontSize: 11.5, color: DyKalTheme.textSecondaryOf(context)),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _storyMoods[path] = picked);
    await StoryMoodStore.save(_storyMoods);
  }

  // ---------- Katalog Musik Gratis ----------
  final _catPlayer = AudioPlayer();
  String? _catPlayingUrl;
  final Set<String> _catDownloading = {};

  Future<void> _openMusicCatalog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => StatefulBuilder(
          builder: (ctx, ss) => Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Katalog Musik Gratis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Sumber: katalog XYSTUDIO (+ Jamendo bila client_id diisi di bawah). Unduh = masuk playlist cerita dengan suasana otomatis.',
                  style: TextStyle(fontSize: 11.5, color: DyKalTheme.textSecondaryOf(ctx)),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: FutureBuilder<List<CatalogTrack>>(
                  future: MusicCatalogService.fetch(),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: DyKalTheme.primary));
                    }
                    final tracks = snap.data ?? [];
                    if (tracks.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Katalog kosong / tidak terjangkau. Tambahkan lagu via URL di file katalog atau isi Jamendo client_id.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DyKalTheme.textSecondaryOf(ctx), fontSize: 12.5),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scroll,
                      itemCount: tracks.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == tracks.length) return _catalogSettingsTile(ss);
                        final t = tracks[i];
                        final playing = _catPlayingUrl == t.url;
                        final downloading = _catDownloading.contains(t.url);
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: DyKalTheme.primary.withValues(alpha: 0.12),
                            child: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: DyKalTheme.primary, size: 20,
                            ),
                          ),
                          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            '${t.artist.isEmpty ? 'Tanpa nama' : t.artist} • ${StoryMoodAnalyzer.labels[t.mood]}',
                            maxLines: 1,
                            style: TextStyle(fontSize: 11, color: DyKalTheme.textSecondaryOf(ctx)),
                          ),
                          onTap: () => _previewCatalog(t, ss),
                          trailing: downloading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.download_outlined, size: 20),
                                  tooltip: 'Unduh ke playlist cerita',
                                  onPressed: () => _downloadCatalog(t, ss),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try { await _catPlayer.stop(); } catch (_) {}
    _catPlayingUrl = null;
  }

  Widget _catalogSettingsTile(StateSetter ss) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      title: const Text('Pengaturan Sumber Katalog', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      children: [
        TextFormField(
          initialValue: MusicCatalogService.defaultCatalogUrl,
          decoration: const InputDecoration(
            labelText: 'URL katalog JSON',
            helperText: 'Skema: {"songs":[{"title","artist","url","mood"}]}',
          ),
          onChanged: (v) => MusicCatalogService.setCatalogUrl(v),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: '',
          decoration: const InputDecoration(
            labelText: 'Jamendo client_id (opsional)',
            helperText: 'Gratis daftar di dev.jamendo.com -> lagu CC legal',
          ),
          onChanged: (v) => MusicCatalogService.setJamendoClientId(v),
        ),
      ],
    );
  }

  Future<void> _previewCatalog(CatalogTrack t, StateSetter ss) async {
    try {
      if (_catPlayingUrl == t.url && _catPlayer.playing) {
        await _catPlayer.pause();
      } else if (_catPlayingUrl == t.url) {
        await _catPlayer.play();
      } else {
        await _catPlayer.stop();
        await _catPlayer.setUrl(t.url);
        await _catPlayer.play();
      }
      ss(() => _catPlayingUrl = t.url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memutar pratinjau (cek internet)')));
      }
    }
  }

  Future<void> _downloadCatalog(CatalogTrack t, StateSetter ss) async {
    ss(() => _catDownloading.add(t.url));
    final path = await MusicCatalogService.download(t);
    ss(() => _catDownloading.remove(t.url));
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unduhan gagal — cek internet / URL lagu')));
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!_storyAudioPaths.contains(path)) _storyAudioPaths.add(path);
      _storyMoods[path] = t.mood;
    });
    await prefs.setStringList('story_audio_playlist', _storyAudioPaths);
    await StoryMoodStore.save(_storyMoods);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${t.title}" masuk playlist cerita (${StoryMoodAnalyzer.labels[t.mood]})')));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _catPlayer.dispose();
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
                child: const Text('Ukuran Teks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 0.9, label: Text('Kecil')),
                    ButtonSegment(value: 1.0, label: Text('Normal')),
                    ButtonSegment(value: 1.12, label: Text('Besar')),
                  ],
                  selected: {_fontScale},
                  onSelectionChanged: (s) => _setFontScale(s.first),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: const Text('Bentuk Bubble Chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _bubbleChip(0, 'Bulat', Icons.circle_outlined),
                    _bubbleChip(1, 'Kotak', Icons.square_outlined),
                    _bubbleChip(2, 'Ekor', Icons.chat_bubble_outline),
                    _bubbleChip(3, 'Pil', Icons.panorama_fish_eye),
                    _bubbleChip(4, 'Abstrak', Icons.auto_awesome),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: BubbleStyle.instance,
                builder: (context, _) => SwitchListTile(
                  secondary: Icon(Icons.format_indent_decrease, color: DyKalTheme.textSecondaryOf(context), size: 20),
                  title: const Text('Status & Waktu di Dalam Bubble', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    BubbleStyle.instance.metaInside ? 'Ala WhatsApp (mepet teks)' : 'Ala iOS (di bawah bubble)',
                    style: TextStyle(fontSize: 11, color: DyKalTheme.textSecondaryOf(context)),
                  ),
                  value: BubbleStyle.instance.metaInside,
                  activeThumbColor: Colors.white,
                  activeTrackColor: DyKalTheme.primary,
                  onChanged: (v) => BubbleStyle.instance.setMetaInside(v),
                ),
              ),
              const Divider(height: 20),
              ListenableBuilder(
                listenable: WallpaperSettings.instance,
                builder: (context, _) {
                  final w = WallpaperSettings.instance;
                  final chatSub = w.chatType == 0
                      ? 'Default (mengikuti tema)'
                      : (w.chatType == 1 ? 'Warna solid' : 'Foto dari galeri');
                  return Column(
                    children: [
                      _tile(
                        Icons.wallpaper_outlined,
                        'Wallpaper Chat',
                        chatSub,
                        _chatWallpaperDialog,
                      ),
                      _tile(
                        Icons.photo_library_outlined,
                        'Latar Belakang Beranda',
                        w.homePath != null ? 'Foto kustom aktif' : 'Default (tanpa latar)',
                        _homeBgSheet,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),

          // 3. PRIVASI & KEAMANAN
          _sectionCard(
            title: 'Privasi & Keamanan',
            icon: Icons.security_outlined,
            children: [
              FutureBuilder<String>(
                future: E2EService.statusLabel(),
                builder: (_, snap) => _infoTile(
                  Icons.lock_outline,
                  'Enkripsi End-to-End Media Chat',
                  snap.data ?? 'Memeriksa...',
                ),
              ),
              // BATCH I: ubah kata sandi akun (re-auth email dulu, wajib aman).
              _tile(
                Icons.password_outlined,
                'Ubah Kata Sandi',
                'Verifikasi sandi lama sebelum mengganti',
                _changePasswordDialog,
              ),
              // BATCH I: opt-in "Lagi buka TikTok" — pasangan bisa melihat
              // aplikasi apa yang sedang kamu buka saat DyKal tertutup.
              SwitchListTile(
                secondary: Icon(
                  Icons.location_searching_outlined,
                  color: _activityShare ? DyKalTheme.primary : DyKalTheme.textGrey,
                ),
                title: const Text('Bagikan Aktivitas Perangkat', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _activityShare
                      ? 'Aktif — pasangan melihat "Lagi buka TikTok/IG/..."'
                      : 'Nonaktif — pasangan hanya melihat Online/Terakhir dilihat',
                  style: TextStyle(fontSize: 11.5, color: DyKalTheme.textSecondaryOf(context)),
                ),
                value: _activityShare,
                activeThumbColor: Colors.white,
                activeTrackColor: DyKalTheme.primary,
                onChanged: _toggleActivityShare,
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
              // BATCH I: hemat data — kompresi upload lebih agresif, media
              // tetap offline-first (lokal menjadi prioritas baca).
              SwitchListTile(
                secondary: Icon(
                  Icons.data_saver_on_outlined,
                  color: _dataSaver ? DyKalTheme.online : DyKalTheme.textGrey,
                ),
                title: const Text('Mode Hemat Data & Cloud', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _dataSaver
                      ? 'Aktif — foto diupload lebih kecil (kualitas 58, maks 1280px)'
                      : 'Normal — kualitas 80, maks 1080p. Media yang sudah diunduh disimpan lokal.',
                  style: TextStyle(fontSize: 11.5, color: DyKalTheme.textSecondaryOf(context)),
                ),
                value: _dataSaver,
                activeThumbColor: Colors.white,
                activeTrackColor: DyKalTheme.online,
                onChanged: (v) async {
                  setState(() => _dataSaver = v);
                  await _saveLocalPref('data_saver', v);
                },
              ),
              _infoTile(
                Icons.folder_outlined,
                'Lokasi Scoped Media',
                'Android/media/com.dykal.app/Dykal/Media/',
              ),
              // --- STATISTIK PENYIMPANAN (permintaan owner: UI bagus + statistik) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total dipakai aplikasi: ${_fmtBytes(_storageTotal)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearCache,
                      icon: const Icon(Icons.cleaning_services_outlined, size: 15, color: Colors.redAccent),
                      label: const Text('Bersihkan Cache', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              _storageBar(),
              ..._storageLegend(),
              const SizedBox(height: 8),
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
                      // BATCH I: chip suasana — dipakai story untuk memilih lagu
                      // yang senada dengan suasana foto.
                      subtitle: GestureDetector(
                        onTap: () => _pickMood(e.key),
                        child: Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: DyKalTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'suasana: ${StoryMoodAnalyzer.labels[_storyMoods[e.value] ?? StoryMoodAnalyzer.guessFromName(e.value)]}',
                            style: TextStyle(fontSize: 10, color: DyKalTheme.primary),
                          ),
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _playingAudioPath == e.value && _audioPlayer.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 18,
                              color: _playingAudioPath == e.value ? DyKalTheme.primary : null,
                            ),
                            onPressed: () => _previewAudio(e.value),
                          ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: FilledButton.icon(
                  onPressed: _openMusicCatalog,
                  icon: const Icon(Icons.library_music_outlined, size: 18),
                  label: const Text('Katalog Musik Gratis (online)'),
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
              _infoTile(
                Icons.favorite_outline,
                'Dibangun oleh',
                'XYSTUDIO — untuk Dyaa & Kall',
              ),
              _tile(
                Icons.article_outlined,
                'Lisensi Open Source',
                'Library pihak ketiga yang dipakai DyKal',
                () => showLicensePage(
                  context: context,
                  applicationName: 'DyKal',
                  applicationLegalese: '© 2026 XYSTUDIO — dibuat dengan cinta untuk Dyaa & Kall',
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// REVISI OWNER: judul section DI LUAR card, isi tetap di dalam card.
  /// (Pola settings modern — judul melayang di atas kontennya.)
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Icon(icon, color: DyKalTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: DyKalTheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: DyKalTheme.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DyKalTheme.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  static const _storageColors = <String, Color>{
    'Cache sementara': Colors.orange,
    'Cache aplikasi': Color(0xFF9E7BFF),
    'Foto & Gambar': Color(0xFFFF6B8A),
    'Video': Color(0xFF7B6CF6),
    'Audio & Voice Note': Color(0xFF00BFA5),
    'Stiker': Color(0xFFFFC857),
    'Wallpaper kustom': Color(0xFF64B5F6),
  };

  /// Bar bersegmen proporsional per kategori (ala storage usage WA).
  Widget _storageBar() {
    final entries = _storage.entries.where((e) => e.value > 0).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: entries.isEmpty
              ? Container(color: DyKalTheme.borderOf(context))
              : Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: ((e.value / _storageTotal) * 1000).round().clamp(1, 1000),
                        child: Container(color: _storageColors[e.key] ?? DyKalTheme.primary),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _storageLegend() {
    return [
      for (final e in _storage.entries)
        if (e.value > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _storageColors[e.key] ?? DyKalTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                Text(_fmtBytes(e.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DyKalTheme.textSecondaryOf(context))),
              ],
            ),
          ),
    ];
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
            onSelectionChanged: (s) {
              ThemeController.instance.setStyle(s.first);
              // Per aturan owner: perubahan gaya antarmuka diikuti instruksi
              // mulai ulang — tidak semua widget menempelkan radius saat runtime.
              _restartHint();
            },
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
        width: 96,
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

    // FIX (owner): nada harus bisa DIPUTAR dulu sebelum dipilih. Channel
    // native dykal/ringtone sudah support play/stop — tinggal disambungkan.
    String? playingUri;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Pilih Nada', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final item = options[i];
                final title = (item['title'] as String?) ?? 'Nada';
                final uri = (item['uri'] as String?) ?? '';
                final isSelected = title == currentVal;
                final isPlaying = playingUri == uri && uri.isNotEmpty && uri != 'asset:default';
                final canPreview = uri.isNotEmpty && uri != 'asset:default';

                return ListTile(
                  dense: true,
                  title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canPreview)
                        IconButton(
                          icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_outline, size: 22, color: DyKalTheme.primary),
                          tooltip: isPlaying ? 'Stop' : 'Putar preview',
                          onPressed: () async {
                            if (isPlaying) {
                              await RingtoneService.stop();
                              setS(() => playingUri = null);
                            } else {
                              await RingtoneService.stop();
                              await RingtoneService.play(uri);
                              setS(() => playingUri = uri);
                            }
                          },
                        ),
                      if (isSelected) const Icon(Icons.check, color: DyKalTheme.primary, size: 18),
                    ],
                  ),
                  onTap: () async {
                    await RingtoneService.stop();
                    playingUri = null;
                    await _saveLocalPref(prefKey, title);
                    onSelect(title);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    // Safety: hentikan preview saat dialog tertutup dengan cara apa pun.
    await RingtoneService.stop();
  }

  /// Dialog wallpaper chat: Default / Warna solid / Foto galeri (Batch C).
  Future<void> _chatWallpaperDialog() async {
    const palette = <Color>[
      Color(0xFFFFF0F3), // pink muda DyKal
      Color(0xFFFFFFFF), // putih
      Color(0xFFFFF3E4), // peach
      Color(0xFFE8F8EF), // mint
      Color(0xFFE8F1FB), // biru muda
      Color(0xFFF3EAFE), // ungu muda
      Color(0xFFFAF6EC), // krem
      Color(0xFF1B1B22), // gelap
    ];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wallpaper Chat', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore, size: 20),
              title: const Text('Default (mengikuti tema)', style: TextStyle(fontSize: 13)),
              onTap: () {
                WallpaperSettings.instance.setChatDefault();
                Navigator.pop(ctx);
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              child: Text('Warna solid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in palette)
                  GestureDetector(
                    onTap: () {
                      WallpaperSettings.instance.setChatColor(c);
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: c,
                      child: c.computeLuminance() > 0.5
                          ? null
                          : const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_outlined, size: 20),
              title: const Text('Foto dari galeri', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Disalin ke penyimpanan privat aplikasi', style: TextStyle(fontSize: 11)),
              onTap: () async {
                final r = await FilePicker.platform.pickFiles(type: FileType.image);
                final path = r?.files.single.path;
                if (path != null) {
                  await WallpaperSettings.instance.setChatImage(File(path));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet latar beranda: pilih foto / hapus kustom (Batch C).
  Future<void> _homeBgSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih foto dari galeri', style: TextStyle(fontSize: 14)),
              onTap: () async {
                final r = await FilePicker.platform.pickFiles(type: FileType.image);
                final path = r?.files.single.path;
                if (path != null) {
                  await WallpaperSettings.instance.setHomeImage(File(path));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            if (WallpaperSettings.instance.homePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Hapus latar kustom', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                onTap: () {
                  WallpaperSettings.instance.clearHome();
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
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
