import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart'; // FIX #15: preview VN sebelum kirim
import 'package:dio/dio.dart'; // uji koneksi beneran (probe /health)
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/dev_logger.dart';
import '../../services/cloudinary_service.dart';
import '../../services/media_saver.dart';
import '../../services/media_cache.dart';
import '../../services/bubble_style.dart';
import '../../services/voice_cache.dart';
import '../../services/wallpaper_settings.dart';
import '../../services/e2e_service.dart';
import '../../services/push_service.dart';
import '../../services/theme_controller.dart';
import '../call/call_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'camera_screen.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/gallery_picker.dart';
import '../profile/view_profile_screen.dart'; // FIX #16: fullscreen partner profile
import 'sticker_edit_screen.dart';
import 'sticker_sheet.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  Timer? _ampTimer;             // sampler amplitudo -> waveform VN asli
  final List<int> _recWave = []; // sampel 0-100 per 200ms
  List<int>? _lastWave;         // sampel rekam terakhir (dipakai saat kirim)
  Timer? _recTimer;
  ChatMessage? _replyTo;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _locked = false; // FIX #15: VN lock saat seret ke atas
  int _recSecs = 0;
  String? _recPath;
  int? _lastMsgCount;
  final Set<String> _savedMedia = {}; // dedup auto-save media masuk
  StreamSubscription? _mediaSub;

  // State gesture voice note ala WhatsApp
  Offset _dragOffset = Offset.zero;
  bool _dragCancel = false;
  bool _dragLock = false;

  // Preview voice note di input field (bukan popup)
  String? _previewVoicePath;
  int? _previewVoiceSecs;
  AudioPlayer? _previewPlayer;
  bool _previewPlaying = false;

  String get _coupleId => AuthService().coupleId ?? '';
  String get _myId => AuthService().myId;
  String get _partnerId => AuthService().partnerId ?? '';
  String get _partnerName => AuthService().partnerName ?? '';

  @override
  void initState() {
    super.initState();
    _setOnline(true);
    _listenMedia(); // auto-save media masuk ke folder lokal
  }

  void _listenMedia() {
    if (_coupleId.isEmpty) return;
    _mediaSub = FirebaseFirestore.instance.collection('chats/$_coupleId/messages').snapshots().listen((qs) {
      for (final d in qs.docChanges) {
        if (d.type != DocumentChangeType.added) continue;
        final m = d.doc.data() as Map<String, dynamic>;
        if (m['fromId'] == _myId) continue;
        final id = d.doc.id;
        if (_savedMedia.contains(id)) continue;
        final voice = m['voiceUrl'] as String?;
        final img = m['imageUrl'] as String?;
        final mt = m['type'] as String?;
        if (voice != null) {
          _savedMedia.add(id);
          // Simpan ke folder lokal + catat mapping URL->path agar bisa
          // diputar OFFLINE (VoiceCache dipakai oleh pemutar).
          MediaSaver.save(voice, type: 'audio').then((path) {
            if (path != null) VoiceCache.put(voice, path);
          });
        } else if (img != null) {
          _savedMedia.add(id);
          if (E2EService.isEncryptedUrl(img)) {
            // E2E: unduh ciphertext -> DEKRIPSI -> simpan plaintext lokal.
            // Backend (Cloudinary/Firestore) hanya pernah pegang ciphertext.
            E2EService.downloadDecrypted(img, ext: mt == 'video' ? 'mp4' : 'webp').then((path) {
              if (path != null) MediaCache.put(img, path);
            });
          } else {
            // Foto/video masuk: simpan lokal + catat mapping URL->path di
            // MediaCache agar bisa DIBUKA OFFLINE (offline-first ala WA).
            MediaSaver.save(img, type: mt == 'video' ? 'video' : 'foto').then((path) {
              if (path != null) MediaCache.put(img, path);
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _setTyping(false);
    // FIX #5: JANGAN set offline di sini — offline cuma pas keluar app (lifecycle MainNav). Keluar chat != offline.
    _mediaSub?.cancel();
    _msgController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _setOnline(bool v) {
    if (_myId.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$_myId').set({'isOnline': v, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  void _setTyping(bool v) {
    if (_myId.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$_myId').set({'isTyping': v}, SetOptions(merge: true));
  }

  void _sendMessage({String? imageUrl, bool viewOnce = false, String? voiceUrl, int? voiceDuration, String? text, String? sticker, String? stickerUrl}) {
    final body = text ?? _msgController.text.trim();
    if (body.isEmpty && imageUrl == null && voiceUrl == null && sticker == null && stickerUrl == null) return;
    final isSticker = sticker != null || stickerUrl != null;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: _myId,
      toId: _partnerId,
      text: sticker ?? (stickerUrl != null ? '' : (voiceUrl != null ? '' : body)),
      type: isSticker ? MessageType.sticker : (voiceUrl != null ? MessageType.voice : (imageUrl != null ? (viewOnce ? MessageType.viewOnce : MessageType.image) : MessageType.text)),
      imageUrl: stickerUrl ?? imageUrl,
      voiceUrl: voiceUrl,
      voiceDuration: voiceDuration,
      replyToId: _replyTo?.id,
      replyToText: _replyTo == null ? null : _replyPreviewText(_replyTo!),
      replyToName: _replyTo == null ? null : (_replyTo!.fromId == _myId ? AuthService().myName : _partnerName),
      status: MessageStatus.sending,
      createdAt: Timestamp.now(),
    );
    if (imageUrl != null) MediaSaver.save(imageUrl); // auto-save foto terkirim ke Dykal Images
    if (voiceUrl != null) MediaSaver.save(voiceUrl, type: 'audio');
    final ref = FirebaseFirestore.instance.collection('chats/$_coupleId/messages').doc(msg.id);
    // Tulis (offline-persist: pesan muncul dgn icon jam). Saat sync -> 'sent' + push.
    ref.set(msg.toMap()).then((_) {
      ref.update({'status': 'sent'});
      final preview = msg.type == MessageType.voice ? 'Voice note' : (msg.type == MessageType.sticker ? 'Stiker' : (msg.imageUrl != null ? 'Foto' : msg.text));
      PushService.notifyPartner(title: AuthService().myName, body: preview);
    });
    _msgController.clear();
    setState(() { _replyTo = null; _isTyping = false; });
    _setTyping(false);
    _checkConn();
  }

  /// Kirim media ala WhatsApp: pesan langsung muncul dengan ikon jam (sending),
  /// upload berjalan di background, lalu status jadi 'sent' + URL terpasang.
  /// Upload media dengan E2E bila pasangan sudah siap (punya public key).
  /// Penanda E2E = URL mengandung '/dykal/e2e/' (nol perubahan skema pesan).
  /// Fallback plaintext otomatis kalau E2E belum siap — chat tidak pernah macet.
  Future<String?> _uploadMaybeE2E(File file, {required String kind, String plainFolder = 'dykal/chat'}) async {
    try {
      File toEncrypt = file;
      if (kind == 'image') {
        // Kompres dulu (jalur kualitas sama dengan upload biasa) baru enkripsi.
        toEncrypt = await CloudinaryService().compressImage(file);
      }
      final enc = await E2EService.encryptFile(toEncrypt);
      if (enc != null) {
        final url = await CloudinaryService().uploadRaw(enc);
        if (url != null) return url;
      }
    } catch (_) {}
    // Fallback: pasangan app lama / raw ditolak preset -> jalur lama.
    if (kind == 'audio') return CloudinaryService().uploadVoiceNote(file);
    return CloudinaryService().uploadImage(file, folder: plainFolder);
  }

  /// Tidak ada dialog loading yang memblokir layar.
  Future<void> _sendWithUpload({
    required String id,
    required MessageType type,
    required Future<String?> Function() upload,
    String? caption,
    int? voiceDuration,
    List<int>? voiceWave,
    bool viewOnce = false,
  }) async {
    final msg = ChatMessage(
      id: id,
      fromId: _myId,
      toId: _partnerId,
      text: caption ?? '',
      type: type,
      imageUrl: null,
      voiceUrl: null,
      voiceDuration: voiceDuration,
      voiceWave: voiceWave,
      replyToId: _replyTo?.id,
      replyToText: _replyTo == null ? null : _replyPreviewText(_replyTo!),
      replyToName: _replyTo == null ? null : (_replyTo!.fromId == _myId ? AuthService().myName : _partnerName),
      status: MessageStatus.sending,
      isViewOnce: viewOnce,
      createdAt: Timestamp.now(),
    );
    final ref = FirebaseFirestore.instance.collection('chats/$_coupleId/messages').doc(id);
    await ref.set(msg.toMap());
    setState(() { _replyTo = null; });

    String? url;
    try {
      url = await upload();
    } catch (_) {
      url = null;
    }
    if (url == null) {
      // Gagal upload -> hapus pesan + kasih tahu user
      try { await ref.delete(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim media. Periksa koneksi.')),
        );
      }
      return;
    }
    await ref.update({
      if (type == MessageType.image || type == MessageType.sticker) 'imageUrl': url,
      if (type == MessageType.voice) 'voiceUrl': url,
      'status': 'sent',
    });
    // Simpan salinan lokal + push notif ke pasangan.
    // MediaCache dicatat juga untuk sisi pengirim: media milik sendiri
    // tetap bisa dibuka OFFLINE (selama ini hanya sisi penerima yang dicatat).
    if (type == MessageType.voice) {
      MediaSaver.save(url, type: 'audio');
    } else if (type == MessageType.image) {
      // 'mediaUrl' local final: promosi null-check 'url' tidak menembus
      // closure .then() (url di-assign ulang di fungsi ini) -> analyzer error.
      final mediaUrl = url;
      MediaSaver.save(mediaUrl, type: 'foto', isPrivate: viewOnce).then((path) {
        if (path != null && !viewOnce) MediaCache.put(mediaUrl, path);
      });
    }
    final preview = type == MessageType.voice
        ? 'Voice note'
        : (type == MessageType.sticker ? 'Stiker' : (caption?.isNotEmpty == true ? caption! : 'Foto'));
    PushService.notifyPartner(title: AuthService().myName, body: preview);
  }

  /// LOGIKA BARU (revisi owner): popup JANGAN tampil saat user sengaja
  /// mematikan internet (ConnectivityResult.none) — itu hak dia. Popup hanya
  /// muncul saat interface NYALA (wifi/seluler) TAPI paket benar-benar tidak
  /// tembus (kuota habis, sinyal bohong, dsb) = koneksi "nyala palsu".
  // Cooldown popup: maksimal sekali per 3 menit (anti spam).
  static DateTime? _connPopupShownAt;

  Future<void> _checkConn() async {
    try {
      final r = await Connectivity().checkConnectivity();
      final noInterface = r.isEmpty || r.every((e) => e == ConnectivityResult.none);
      if (noInterface) return; // user mematikan koneksi -> diamkan (offline mode WA)

      // BATCH H (keluhan owner: "popup muncul padahal kuota ada"):
      // dulu SATU probe 4 dtk ke worker — DNS dingin/cold-start Cloudflare
      // bisa menembus 4 dtk -> SALAH TUDUH offline. Sekarang: 2 endpoint
      // berbeda (worker + Google 204), masing-masing 6 dtk, 2 kali percobaan.
      // Popup hanya kalau SEMUA percobaan gagal -> hampir mustahil salah tuduh.
      Future<bool> probe(String url) => Dio()
          .head(url)
          .timeout(const Duration(seconds: 6))
          .then((_) => true)
          .catchError((_) => false);

      Future<bool> tryOnce() async => await probe('https://push.xystudio.my.id/health') ||
          await probe('https://clients3.google.com/generate_204');

      var ok = await tryOnce();
      if (!ok) {
        await Future.delayed(const Duration(milliseconds: 1200));
        ok = await tryOnce(); // percobaan kedua (jeda agar DNS/radio stabil)
      }
      if (!ok && mounted) {
        final last = _connPopupShownAt;
        if (last != null && DateTime.now().difference(last).inMinutes < 3) return;
        _connPopupShownAt = DateTime.now();
        showDialog(context: context, builder: (_) => AlertDialog(
          icon: const Icon(Icons.wifi_tethering_off, color: Color(0xFFFF6B8A), size: 40),
          title: const Text('Internet nyala tapi tak tembus'),
          content: const Text('WiFi/data nyala tapi paket tidak sampai ke dua server uji — kemungkinan kuota habis, jaringan macet, atau provider sedang gangguan. Pesan tertahan (ikon jam) dan terkirim otomatis saat akses pulih.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
      }
    } catch (_) {}
  }

  Future<void> _showPartnerProfile() async {
    if (_partnerId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewProfileScreen(partnerId: _partnerId)),
    );
  }



  void _pickSticker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StickerSheet(
        onEmoji: (e) {
          Navigator.pop(context);
          _sendMessage(sticker: e);
        },
        onSendLocal: (f) {
          Navigator.pop(context);
          _sendLocalSticker(f);
        },
        onMake: () {
          Navigator.pop(context);
          _buatStiker();
        },
      ),
    );
  }

  Future<void> _buatStiker() async {
    final file = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => const GalleryPickerScreen()));
    if (file == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => StickerEditScreen(image: file)));
  }

  Future<void> _sendLocalSticker(File f) async {
    // Langsung muncul sebagai stiker dengan ikon jam; upload di background.
    await _sendWithUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.sticker,
      // Stiker ikut E2E (owner): di lokal sudah .webp.crypt15, ke Cloudinary
      // sekarang juga terenkripsi — bukan lagi webp polos.
      upload: () => _uploadMaybeE2E(f, kind: 'image', plainFolder: 'dykal/stiker'),
    );
  }

  /// Mainkan sound efek dari aset (vn_start, vn_sent, vn_cancel, msg_sent).
  Future<void> _playSound(String asset) async {
    try {
      final p = AudioPlayer();
      await p.setAsset(asset);
      await p.play();
      p.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed)
          .then((_) => p.dispose()).catchError((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> _startRec() async {
    if (!await _recorder.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izinkan akses mikrofon dulu')));
      return;
    }
    await _playSound('assets/sounds/vn_start.wav');
    final dir = await getTemporaryDirectory();
    _recPath = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: _recPath!);
    setState(() { _isRecording = true; _recSecs = 0; _locked = false; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _recSecs++));
    // Sampel amplitudo setiap 200ms -> GELOMBANG ASLI di gelembung VN
    // (permintaan owner; dulu geometri statis). dBFS -50..0 dinormalisasi 0-100.
    _recWave.clear();
    _ampTimer?.cancel();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      try {
        final a = await _recorder.getAmplitude();
        final norm = ((a.current + 50) / 50).clamp(0.0, 1.0);
        if (_recWave.length < 90) _recWave.add((norm * 100).round());
      } catch (_) {}
    });
    _setRecording(true);
  }

  Future<void> _discardRec() async {
    if (!_isRecording) return;
    await _playSound('assets/sounds/vn_cancel.wav');
    _recTimer?.cancel();
    _ampTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    setState(() { _isRecording = false; _locked = false; });
    _setRecording(false);
  }

  void _setRecording(bool v) {
    if (_myId.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$_myId').set({'isRecording': v}, SetOptions(merge: true));
  }

  Future<void> _stopRec({bool send = true}) async {
    if (!_isRecording) return;
    _recTimer?.cancel();
    _ampTimer?.cancel();
    _lastWave = List.of(_recWave);
    final path = await _recorder.stop();
    final secs = _recSecs;
    setState(() { _isRecording = false; _locked = false; });
    _setRecording(false);
    if (path == null) return;
    await _playSound('assets/sounds/vn_sent.wav');
    if (send) {
      // Voice note langsung muncul (ikon jam), upload di background.
      await _sendWithUpload(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.voice,
        voiceDuration: secs,
        voiceWave: _lastWave,
        upload: () => _uploadMaybeE2E(File(path), kind: 'audio'),
      );
    } else {
      _showVoicePreview(path, secs); // FIX #15: preview dulu sebelum kirim
    }
  }

  String _fmtRec(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  /// Preview voice note tampil di INPUT FIELD (bukan popup):
  /// tombol play/pause, durasi, sampah (hapus), kirim.
  void _showVoicePreview(String path, int secs) {
    _previewPlayer?.dispose();
    _previewPlayer = AudioPlayer();
    setState(() {
      _previewVoicePath = path;
      _previewVoiceSecs = secs;
      _previewPlaying = false;
    });
  }

  Future<void> _togglePreviewPlay() async {
    final player = _previewPlayer;
    if (player == null || _previewVoicePath == null) return;
    try {
      if (_previewPlaying) {
        await player.pause();
        setState(() => _previewPlaying = false);
      } else {
        await player.setFilePath(_previewVoicePath!);
        await player.play();
        setState(() => _previewPlaying = true);
        player.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed && mounted) {
            setState(() => _previewPlaying = false);
          }
        });
      }
    } catch (_) {}
  }

  void _clearVoicePreview() {
    _previewPlayer?.dispose();
    _previewPlayer = null;
    setState(() {
      _previewVoicePath = null;
      _previewVoiceSecs = null;
      _previewPlaying = false;
    });
  }

  Future<void> _sendVoicePreview() async {
    final path = _previewVoicePath;
    final secs = _previewVoiceSecs;
    if (path == null || secs == null) return;
    _previewPlayer?.dispose();
    _previewPlayer = null;
    setState(() {
      _previewVoicePath = null;
      _previewVoiceSecs = null;
      _previewPlaying = false;
    });
    await _sendWithUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.voice,
      voiceDuration: secs,
      voiceWave: _lastWave,
      upload: () => _uploadMaybeE2E(File(path), kind: 'audio'),
    );
  }

  void _onChanged(String v) {
    final typing = v.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _setTyping(typing);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_coupleId.isEmpty || _partnerId.isEmpty) {
      return Scaffold(body: Center(child: Text('Belum terhubung', style: TextStyle(color: DyKalTheme.textGrey))));
    }
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DyKalTheme.backgroundDark
          : DyKalTheme.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: WallpaperSettings.instance,
          builder: (context, _) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            // Wallpaper kustom (warna/foto dari galeri) menimpa aset bawaan.
            final deco = WallpaperSettings.instance.chatDecoration(dark: dark) ??
                BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(dark
                        ? 'assets/backgrounds/chat_bg_dark.webp'
                        : 'assets/backgrounds/chat_bg_light.webp'),
                    fit: BoxFit.cover,
                    opacity: dark ? 0.55 : 0.9,
                  ),
                );
            return Container(
          decoration: deco,
          child: Column(
            children: [
              _header(),
              Expanded(child: _list()),
              if (_replyTo != null) _replyPreview(),
              if (_isRecording && _locked) _recordingBar(),
              if (_isRecording && !_locked) _recordingOverlay(),
              _input(),
            ],
          ),
            );
          },
        ),
      ),
    );
  }

  // FIX #3: reply ke VN/foto/stiker kasih placeholder (sebelumnya kosong = "error")
  String _replyPreviewText(ChatMessage m) {
    if (m.type == MessageType.voice) return "Voice note";
    if (m.type == MessageType.image) return m.isViewOnce ? "Foto sekali lihat" : "Foto";
    if (m.type == MessageType.sticker) return "Stiker";
    return m.text.isEmpty ? "Pesan" : m.text;
  }

  void _showThemeDialog() {
    showDialog(context: context, builder: (_) => SimpleDialog(
      title: const Text("Ubah Tema"),
      children: [
        SimpleDialogOption(onPressed: () { ThemeController.instance.set(ThemeMode.system); Navigator.pop(context); }, child: const Text("Sistem")),
        SimpleDialogOption(onPressed: () { ThemeController.instance.set(ThemeMode.light); Navigator.pop(context); }, child: const Text("Terang")),
        SimpleDialogOption(onPressed: () { ThemeController.instance.set(ThemeMode.dark); Navigator.pop(context); }, child: const Text("Gelap")),
      ],
    ));
  }

  void _showBubbleDialog() async {
    final prefs = await SharedPreferences.getInstance();
    int cur = prefs.getInt("bubble_style") ?? 0;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (_, setS) => SimpleDialog(
      title: const Text("Gaya Bubble"),
      children: [
        for (final e in const [("Bulat", 0), ("Kotak", 1), ("Ekor", 2), ("Pil", 3), ("Abstrak", 4)])
          SimpleDialogOption(onPressed: () async {
            await BubbleStyle.instance.set(e.$2); // satu sumber kebenaran
            setS(() => cur = e.$2);
            if (mounted) setState(() {}); // rebuild gelembung langsung
          },
            child: Row(children: [Text(e.$1), const Spacer(), if (cur == e.$2) Icon(Icons.check, color: DyKalTheme.primary, size: 18)])),
      ],
    )));
  }

  void _confirmClearChat() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Bersihkan chat?"),
      content: const Text("Semua pesan akan dihapus permanen untuk kamu & dia."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () { Navigator.pop(context); _clearChat(); }, child: const Text("Bersihkan")),
      ],
    ));
  }

  Future<void> _clearChat() async {
    final col = FirebaseFirestore.instance.collection("chats/$_coupleId/messages");
    final snap = await col.get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
          GestureDetector(
            onTap: _showPartnerProfile,
            child: CircleAvatar(radius: 20, backgroundColor: DyKalTheme.primary, backgroundImage: AuthService().partnerPhotoUrl != null ? CachedNetworkImageProvider(AuthService().partnerPhotoUrl!) : null, child: AuthService().partnerPhotoUrl == null ? Text(_partnerName.isNotEmpty ? _partnerName[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)) : null),
          ),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.doc('presence/$_partnerId').snapshots(),
            builder: (_, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final online = data?['isOnline'] ?? false;
              final typing = data?['isTyping'] ?? false;
              final rec = data?['isRecording'] ?? false;
              final net = data?['net'] as String? ?? 'none'; // wifi/mobile/none
              final lastSeen = data?['lastSeen'];
              // Status pintar (permintaan owner):
              // - online + jenis koneksi (WiFi/Seluler)
              // - offline jujur: "Terakhir dilihat ..." (kemungkinan data mati)
              String sub;
              if (typing) {
                sub = 'mengetik...';
              } else if (rec) {
                sub = 'merekam audio...';
              } else if (online) {
                final via = net == 'wifi' ? 'WiFi' : (net == 'mobile' ? 'data seluler' : 'online');
                sub = 'Online · $via';
              } else if (lastSeen is Timestamp) {
                final dt = lastSeen.toDate();
                sub = 'Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
              } else {
                sub = 'offline';
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(_partnerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(width: 6), Icon(Icons.favorite, color: DyKalTheme.primary, size: 14)]),
                if (typing)
                  Row(children: [TypingDots(color: DyKalTheme.primary), const SizedBox(width: 6), Text('mengetik', style: TextStyle(fontSize: 12, color: DyKalTheme.primary))])
                else
                  Text(sub, style: TextStyle(fontSize: 12, color: DyKalTheme.textGrey)),
              ]);
            },
          )),
          IconButton(onPressed: () => Navigator.pushNamed(context, '/audioCall', arguments: {'isCaller': true, 'type': 'audio'}), icon: Icon(Icons.phone, color: DyKalTheme.primary, size: 22)),
          IconButton(onPressed: () => Navigator.pushNamed(context, '/videoCall', arguments: {'isCaller': true, 'type': 'video'}), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: DyKalTheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.videocam, color: Colors.white, size: 18))),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: DyKalTheme.textPrimaryOf(context)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline), title: Text('Lihat Profil'), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'log', child: ListTile(leading: Icon(Icons.history), title: Text('Log Panggilan'), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'theme', child: ListTile(leading: Icon(Icons.palette_outlined), title: Text('Ubah Tema'), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'bubble', child: ListTile(leading: Icon(Icons.chat_bubble_outline), title: Text('Gaya Bubble'), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.cleaning_services_outlined), title: Text('Bersihkan Chat'), dense: true, contentPadding: EdgeInsets.zero)),
            ],
            onSelected: (v) {
              if (v == 'profile') _showPartnerProfile();
              else if (v == 'log') Navigator.push(context, MaterialPageRoute(builder: (_) => const CallLogScreen()));
              else if (v == 'theme') _showThemeDialog();
              else if (v == 'bubble') _showBubbleDialog();
              else if (v == 'clear') _confirmClearChat();
            },
          ),
        ]),
      );

  Widget _list() => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats/$_coupleId/messages').snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            DevLogger.instance.error('chat', 'Stream ERROR', snap.error);
            AppLogger.error('chat_stream', snap.error);
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off, size: 48, color: DyKalTheme.textGrey.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('Gagal memuat chat', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: SelectableText('Error: ${snap.error}', style: const TextStyle(fontSize: 11, color: Colors.red), textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Text('Log tersimpan di Android/media/com.dykal.app/logs/app.log', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 10)),
            ])));
          }
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: DyKalTheme.primary));
          final rawDocs = snap.data!.docs;
          rawDocs.sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['createdAt'];
            final tb = (b.data() as Map<String, dynamic>)['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
            return 0;
          });
          final docs = rawDocs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: DyKalTheme.textGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Belum ada chat', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Kirim pesan pertama ke $_partnerName', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
          ]));
          if (_lastMsgCount != null && docs.length > _lastMsgCount!) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            });
          }
          _lastMsgCount = docs.length;
          return ListView.builder(
            controller: _scrollController, reverse: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final msg = ChatMessage.fromMap(docs[i].data() as Map<String, dynamic>);
              final isMe = msg.fromId == _myId;
              if (!isMe && msg.status != MessageStatus.read) {
                docs[i].reference.update({'status': 'read'});
              }
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        onSwipeReply: () => setState(() => _replyTo = msg),
                        onLove: () => docs[i].reference.update({'isLoved': !msg.isLoved}),
                        onEdit: (newText) => docs[i].reference.update({'text': newText, 'isEdited': true}),
                        onDelete: () => docs[i].reference.update({'isDeleted': true, 'text': 'Pesan ini telah dihapus'}),
                        onDeleteForMe: () => docs[i].reference.update({
                          'deletedFor': FieldValue.arrayUnion([_myId]),
                        }),
                        onReact: (emoji) => docs[i].reference.update({'reaction': emoji.isEmpty ? FieldValue.delete() : emoji}),
                        onDownload: msg.imageUrl != null ? () async {
                          final p = await MediaSaver.save(msg.imageUrl!, type: 'foto');
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p == null ? 'Gagal menyimpan' : 'Foto tersimpan')));
                        } : null,
                      );
            },
          );
        },
      );

  Widget _replyPreview() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: DyKalTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: DyKalTheme.primary, width: 3))),
        child: Row(children: [
          Icon(Icons.reply, size: 16, color: DyKalTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Membalas', style: TextStyle(fontSize: 11, color: DyKalTheme.primary, fontWeight: FontWeight.w700)), Text(_replyPreviewText(_replyTo!), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))])),
          IconButton(onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close, size: 16)),
        ]),
      );

  /// Overlay saat merekam (belum terkunci): target batal di kiri,
  /// target kunci di kanan, timer + instruksi. Ikon menyala sesuai arah geser.
  Widget _recordingOverlay() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: DyKalTheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dragCancel ? Colors.redAccent : Colors.transparent,
              ),
              child: Icon(
                Icons.delete_outline,
                color: _dragCancel ? Colors.white : Colors.redAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merekam ${_fmtRec(_recSecs)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Lepas = kirim · Geser atas = kunci · Geser kiri = batal',
                    style: TextStyle(fontSize: 11, color: DyKalTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dragLock ? DyKalTheme.primary : Colors.transparent,
              ),
              child: Icon(
                Icons.lock_outline,
                color: _dragLock ? Colors.white : DyKalTheme.primary,
                size: 22,
              ),
            ),
          ],
        ),
      );

  Widget _recordingBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: DyKalTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Icon(_locked ? Icons.lock : Icons.fiber_manual_record, color: DyKalTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_locked ? 'Terkunci ${_fmtRec(_recSecs)} — tap STOP untuk preview' : 'Merekam ${_fmtRec(_recSecs)} — lepas=kirim · geser kiri=batal · atas=kunci', style: TextStyle(color: DyKalTheme.primary, fontWeight: FontWeight.w600, fontSize: 12))),
          if (_locked) GestureDetector(onTap: () => _stopRec(send: false), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.stop_circle, color: Colors.red, size: 22))),
        ]),
      );

  Future<void> _openCamera() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result == null || !mounted) return;
    final viewOnce = result['viewOnce'] as bool? ?? false;
    await _sendWithUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.image,
      caption: result['caption'] as String?,
      viewOnce: viewOnce,
      upload: () => _uploadMaybeE2E(
        File(result['localPath'] as String),
        kind: 'image',
        plainFolder: viewOnce ? 'dykal/view_once' : 'dykal/chat',
      ),
    );
  }

  void _openAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attachItem(Icons.camera_alt_rounded, 'Kamera', const Color(0xFF00D68F), () {
                Navigator.pop(ctx);
                _openCamera();
              }),
              _attachItem(Icons.insert_drive_file_rounded, 'Dokumen', const Color(0xFF7B6CF6), () async {
                Navigator.pop(ctx);
                final res = await FilePicker.platform.pickFiles();
                if (res != null && res.files.single.path != null) {
                  final file = File(res.files.single.path!);
                  final name = res.files.single.name;
                  await _sendWithUpload(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: MessageType.image,
                    caption: name,
                    upload: () => _uploadMaybeE2E(file, kind: 'image', plainFolder: 'dykal/documents'),
                  );
                }
              }),
              _attachItem(Icons.music_note_rounded, 'Audio', const Color(0xFFFFC857), () async {
                Navigator.pop(ctx);
                final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                if (res != null && res.files.single.path != null) {
                  final file = File(res.files.single.path!);
                  await _sendWithUpload(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: MessageType.voice,
                    upload: () => _uploadMaybeE2E(file, kind: 'audio'),
                  );
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _input() {
    // Preview voice note: input field berubah jadi bar preview (play, durasi, hapus, kirim)
    if (_previewVoicePath != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.mic_none, color: DyKalTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DyKalTheme.backgroundDark
                      : DyKalTheme.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DyKalTheme.borderOf(context)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_previewPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: DyKalTheme.primary, size: 30),
                      onPressed: _togglePreviewPlay,
                      tooltip: _previewPlaying ? 'Jeda' : 'Putar',
                    ),
                    const SizedBox(width: 4),
                    Text('${_fmtRec(_previewVoiceSecs ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Preview voice note', style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context))),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: _clearVoicePreview,
                      tooltip: 'Hapus',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _sendVoicePreview,
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: _pickSticker,
              icon: Icon(Icons.emoji_emotions_outlined, color: DyKalTheme.primary, size: 24),
              tooltip: 'Stiker & Emoji',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DyKalTheme.backgroundDark
                      : DyKalTheme.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DyKalTheme.borderOf(context)),
                ),
                child: TextField(
                  controller: _msgController,
                  onChanged: _onChanged,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(color: DyKalTheme.textPrimaryOf(context)),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan...',
                    hintStyle: TextStyle(fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: _openAttachmentMenu,
              icon: Icon(Icons.attach_file_rounded, color: DyKalTheme.textSecondaryOf(context), size: 22),
              tooltip: 'Lampiran',
            ),
            IconButton(
              onPressed: _openCamera,
              icon: Icon(Icons.camera_alt_rounded, color: DyKalTheme.primary, size: 22),
              tooltip: 'Kamera',
            ),
            ValueListenableBuilder(
              valueListenable: _msgController,
              builder: (_, v, __) => v.text.trim().isNotEmpty
                  ? GestureDetector(
                      onTap: () => _sendMessage(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    )
                  : Transform.translate(
                      offset: _dragOffset,
                      child: GestureDetector(
                        onTap: () {
                          if (!_isRecording) {
                            _startRec();
                          } else {
                            _stopRec(send: false);
                          }
                        },
                        // Gesture ala WhatsApp: tahan=lupa → lepas=kirim,
                        // geser ke atas=mengunci, geser ke kiri=membatalkan.
                        onLongPressStart: (_) {
                          setState(() {
                            _dragOffset = Offset.zero;
                            _dragCancel = false;
                            _dragLock = false;
                          });
                          _startRec();
                        },
                        onLongPressMoveUpdate: (d) {
                          if (!_isRecording) return;
                          final dx = d.offsetFromOrigin.dx;
                          final dy = d.offsetFromOrigin.dy;
                          final wasCancel = _dragCancel;
                          final wasLock = _dragLock;
                          setState(() {
                            _dragOffset = Offset(dx.clamp(-90.0, 0.0), dy.clamp(-150.0, 0.0));
                            _dragCancel = dx < -70 && !_dragLock;
                            _dragLock = dy < -60 && !_dragCancel;
                          });
                          // Haptic saat MASUK zona kunci/batal — jari "kerasakan"
                          // perpindahan mode (feedback yang sebelumnya tidak ada)
                          if (_dragLock && !wasLock) HapticFeedback.mediumImpact();
                          if (_dragCancel && !wasCancel) HapticFeedback.lightImpact();
                        },
                        onLongPressEnd: (_) {
                          if (!_isRecording) return;
                          if (_dragCancel) {
                            _discardRec();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Voice note dibatalkan')),
                              );
                            }
                          } else if (_dragLock) {
                            setState(() {
                              _locked = true;
                              _dragOffset = Offset.zero;
                              _dragCancel = false;
                              _dragLock = false;
                            });
                          } else {
                            _stopRec(send: true);
                          }
                          setState(() {
                            _dragOffset = Offset.zero;
                            _dragCancel = false;
                            _dragLock = false;
                          });
                        },
                        onLongPressCancel: () {
                          _discardRec();
                          setState(() {
                            _dragOffset = Offset.zero;
                            _dragCancel = false;
                            _dragLock = false;
                          });
                        },
                        child: AnimatedScale(
                          scale: _isRecording ? 1.25 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? (_dragCancel ? Colors.redAccent : (_dragLock ? DyKalTheme.primary : Colors.red))
                                  : DyKalTheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              boxShadow: _isRecording
                                  ? [BoxShadow(color: Colors.red.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 2)]
                                  : const [],
                            ),
                            child: Icon(
                              _isRecording
                                  ? (_dragLock ? Icons.lock_rounded : (_dragCancel ? Icons.delete_rounded : Icons.stop))
                                  : Icons.mic_rounded,
                              color: _isRecording ? Colors.white : DyKalTheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
  }
}
