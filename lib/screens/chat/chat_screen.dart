import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart'; // FIX #15: preview VN sebelum kirim
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/dev_logger.dart';
import '../../services/cloudinary_service.dart';
import '../../services/media_saver.dart';
import '../../services/push_service.dart';
import '../../services/theme_controller.dart';
import '../call/call_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'camera_screen.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/gallery_picker.dart';
import 'image_send_screen.dart';
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
  Timer? _recTimer;
  ChatMessage? _replyTo;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _locked = false; // FIX #15: VN lock saat seret ke atas
  bool _cancelled = false; // FIX spec: VN swipe-kiri = batal
  int _recSecs = 0;
  String? _recPath;
  int? _lastMsgCount;
  final Set<String> _savedMedia = {}; // dedup auto-save media masuk
  StreamSubscription? _mediaSub;

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
        if (voice != null) { _savedMedia.add(id); MediaSaver.save(voice, type: 'audio'); }
        else if (img != null) { _savedMedia.add(id); MediaSaver.save(img, type: mt == 'video' ? 'video' : 'foto'); }
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

  Future<void> _checkConn() async {
    try {
      final r = await Connectivity().checkConnectivity();
      final offline = r.isEmpty || r.every((e) => e == ConnectivityResult.none);
      if (offline && mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          icon: const Icon(Icons.wifi_off, color: Color(0xFFFF6B8A), size: 40),
          title: const Text('Tidak ada koneksi internet'),
          content: const Text('Pesan tertahan (ikon jam ⏳). Nyalakan data seluler atau sambungkan ke WiFi — pesan terkirim otomatis saat online.'),
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

  Future<void> _pickImage() async {
    final file = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: false)));
    if (file == null || !mounted) return;
    final res = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ImageSendScreen(image: file)));
    if (!mounted || res == null) return;
    _sendMessage(imageUrl: res['url'] as String, viewOnce: res['viewOnce'] as bool, text: (res['caption'] as String?)?.isEmpty == true ? null : res['caption'] as String?);
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
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A))));
    final url = await CloudinaryService().uploadImage(f, folder: 'dykal/stiker');
    if (!mounted) return;
    Navigator.pop(context);
    if (url != null) {
      _sendMessage(stickerUrl: url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal upload stiker')));
    }
  }

  Future<void> _startRec() async {
    if (!await _recorder.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izinkan akses mikrofon dulu')));
      return;
    }
    final dir = await getTemporaryDirectory();
    _recPath = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: _recPath!);
    setState(() { _isRecording = true; _recSecs = 0; _locked = false; _cancelled = false; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _recSecs++));
    _setRecording(true);
  }

  Future<void> _discardRec() async {
    if (!_isRecording) return;
    _recTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    setState(() { _isRecording = false; _locked = false; _cancelled = false; });
    _setRecording(false);
  }

  void _setRecording(bool v) {
    if (_myId.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$_myId').set({'isRecording': v}, SetOptions(merge: true));
  }

  Future<void> _stopRec({bool send = true}) async {
    if (!_isRecording) return;
    _recTimer?.cancel();
    final path = await _recorder.stop();
    final secs = _recSecs;
    setState(() { _isRecording = false; _locked = false; });
    _setRecording(false);
    if (path == null) return;
    if (send) {
      final url = await CloudinaryService().uploadVoiceNote(File(path));
      if (url != null) _sendMessage(voiceUrl: url, voiceDuration: secs);
    } else {
      _showVoicePreview(path, secs); // FIX #15: preview dulu sebelum kirim
    }
  }

  String _fmtRec(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _showVoicePreview(String path, int secs) {
    final player = AudioPlayer();
    bool playing = false;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (_, setS) => AlertDialog(
      title: const Text('Preview Voice Note'),
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 40, color: DyKalTheme.primary),
          onPressed: () async {
            try {
              if (!playing) { await player.setFilePath(path); await player.play(); setS(() => playing = true); }
              else { await player.pause(); setS(() => playing = false); }
            } catch (_) {}
          }),
        const SizedBox(width: 8),
        Text('${_fmtRec(secs)} • putar dulu', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () { player.dispose(); Navigator.pop(context); }, child: const Text('Buang')),
        FilledButton(onPressed: () async {
          player.dispose(); Navigator.pop(context);
          final url = await CloudinaryService().uploadVoiceNote(File(path));
          if (url != null) _sendMessage(voiceUrl: url, voiceDuration: secs);
        }, child: const Text('Kirim')),
      ],
    ))).then((_) => player.dispose());
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
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/illustrations/chat_bg.webp'),
              fit: BoxFit.cover,
              opacity: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.08,
            ),
          ),
          child: Column(
            children: [
              _header(),
              Expanded(child: _list()),
              if (_replyTo != null) _replyPreview(),
              if (_isRecording) _recordingBar(),
              _input(),
            ],
          ),
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
        for (final e in const [("Bulat", 0), ("Kotak", 1), ("Ekor", 2)])
          SimpleDialogOption(onPressed: () async { await prefs.setInt("bubble_style", e.$2); setS(() => cur = e.$2); },
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
              String sub = typing ? 'mengetik...' : rec ? 'merekam audio...' : online ? 'online' : 'offline';
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
    if (result != null) {
      _sendMessage(
        imageUrl: result['url'],
        text: result['caption'],
        viewOnce: result['viewOnce'] ?? false,
      );
    }
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
              _attachItem(Icons.photo_library_rounded, 'Galeri', DyKalTheme.primary, () {
                Navigator.pop(ctx);
                _pickImage();
              }),
              _attachItem(Icons.camera_alt_rounded, 'Kamera', const Color(0xFF00D68F), () {
                Navigator.pop(ctx);
                _openCamera();
              }),
              _attachItem(Icons.insert_drive_file_rounded, 'Dokumen', const Color(0xFF7B6CF6), () async {
                Navigator.pop(ctx);
                final res = await FilePicker.platform.pickFiles();
                if (res != null && res.files.single.path != null) {
                  final file = File(res.files.single.path!);
                  final url = await CloudinaryService().uploadImage(file, folder: 'dykal/documents');
                  if (url != null) _sendMessage(imageUrl: url, text: res.files.single.name);
                }
              }),
              _attachItem(Icons.music_note_rounded, 'Audio', const Color(0xFFFFC857), () async {
                Navigator.pop(ctx);
                final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                if (res != null && res.files.single.path != null) {
                  final file = File(res.files.single.path!);
                  final url = await CloudinaryService().uploadVoiceNote(file);
                  if (url != null) _sendMessage(voiceUrl: url, voiceDuration: 10);
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

  Widget _input() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          color: DyKalTheme.cardOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _pickSticker,
              icon: Icon(Icons.emoji_emotions_outlined, color: DyKalTheme.primary, size: 24),
              tooltip: 'Stiker & Emoji',
            ),
            IconButton(
              onPressed: _openAttachmentMenu,
              icon: Icon(Icons.attach_file_rounded, color: DyKalTheme.textSecondaryOf(context), size: 22),
              tooltip: 'Lampiran',
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
            const SizedBox(width: 4),
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
                  : GestureDetector(
                      onTap: () {
                        if (!_isRecording) _startRec();
                        else _stopRec(send: false);
                      },
                      onLongPressStart: (_) => _startRec(),
                      onLongPressMoveUpdate: (d) {
                        if (d.offsetFromOrigin.dx < -60 && !_cancelled) setState(() => _cancelled = true);
                        else if (d.offsetFromOrigin.dy < -50 && !_locked && !_cancelled) setState(() => _locked = true);
                      },
                      onLongPressEnd: (_) {
                        if (_cancelled) {
                          _discardRec();
                        } else if (!_locked) {
                          _stopRec(send: true);
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : DyKalTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic_rounded,
                          color: _isRecording ? Colors.white : DyKalTheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
}
