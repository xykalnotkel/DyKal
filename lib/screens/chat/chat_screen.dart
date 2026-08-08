import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/media_saver.dart';
import '../../services/push_service.dart';
import '../../widgets/typing_indicator.dart';
import 'image_send_screen.dart';
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
  ChatMessage? _replyTo;
  bool _isTyping = false;
  bool _isRecording = false;
  int _recSecs = 0;
  String? _recPath;
  int? _lastMsgCount;

  String get _coupleId => AuthService().coupleId ?? '';
  String get _myId => AuthService().myId;
  String get _partnerId => AuthService().partnerId ?? '';
  String get _partnerName => AuthService().partnerName ?? 'Ayang';

  @override
  void initState() {
    super.initState();
    _setOnline(true);
  }

  @override
  void dispose() {
    _setTyping(false);
    _setOnline(false);
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

  void _sendMessage({String? imageUrl, bool viewOnce = false, String? voiceUrl, int? voiceDuration, String? text, String? sticker}) {
    final body = text ?? _msgController.text.trim();
    if (body.isEmpty && imageUrl == null && voiceUrl == null && sticker == null) return;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: _myId,
      toId: _partnerId,
      text: sticker ?? (voiceUrl != null ? '' : body),
      type: sticker != null ? MessageType.sticker : (voiceUrl != null ? MessageType.voice : (imageUrl != null ? (viewOnce ? MessageType.viewOnce : MessageType.image) : MessageType.text)),
      imageUrl: imageUrl,
      voiceUrl: voiceUrl,
      voiceDuration: voiceDuration,
      replyToId: _replyTo?.id,
      replyToText: _replyTo?.text,
      replyToName: _replyTo == null ? null : (_replyTo!.fromId == _myId ? AuthService().myName : _partnerName),
      status: MessageStatus.sending,
      createdAt: Timestamp.now(),
    );
    final ref = FirebaseFirestore.instance.collection('chats/$_coupleId/messages').doc(msg.id);
    // Tulis (offline-persist: pesan muncul dgn icon jam). Saat sync -> 'sent' + push.
    ref.set(msg.toMap()).then((_) {
      ref.update({'status': 'sent'});
      final preview = msg.type == MessageType.voice ? '🎙️ Voice note' : (msg.imageUrl != null ? '📷 Foto' : msg.text);
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
    final snap = await FirebaseFirestore.instance.doc('users/$_partnerId').get();
    final d = snap.data();
    final name = d?['displayName'] ?? _partnerName;
    final email = d?['email'] ?? '';
    final photo = d?['photoUrl'];
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 50, backgroundColor: DyKalTheme.primary, backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null, child: photo == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w800)) : null),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (email.toString().isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.email, size: 14, color: DyKalTheme.textGrey), const SizedBox(width: 6), Flexible(child: Text(email, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 13), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.doc('presence/$_partnerId').snapshots(), builder: (_, s) {
          final data = s.data?.data() as Map<String, dynamic>?;
          final online = data?['isOnline'] ?? false;
          return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (online ? DyKalTheme.online : DyKalTheme.textGrey).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 8, color: online ? DyKalTheme.online : DyKalTheme.textGrey), const SizedBox(width: 6), Text(online ? 'Online' : 'Offline', style: TextStyle(color: online ? DyKalTheme.online : DyKalTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 12))]));
        }),
      ]))),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final res = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => ImageSendScreen(image: File(xfile.path))));
    if (!mounted || res == null) return;
    _sendMessage(imageUrl: res['url'] as String, viewOnce: res['viewOnce'] as bool, text: (res['caption'] as String?)?.isEmpty == true ? null : res['caption'] as String?);
  }

  void _pickSticker() {
    const stickers = ['❤️', '😍', '🥰', '😘', '💕', '💑', '🥺', '😭', '😂', '🤣', '🔥', '✨', '🌹', '💍', '😻', '🤩', '😴', '🤗', '😋', '🙏', '👏', '🫶', '💋', '🎂', '🎁', '🌙', '⭐', '🥳'];
    showModalBottomSheet(
      context: context,
      backgroundColor: DyKalTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Stiker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: stickers.map((e) => GestureDetector(
              onTap: () { Navigator.pop(context); _sendMessage(sticker: e); },
              child: Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DyKalTheme.borderSoft)), alignment: Alignment.center, child: Text(e, style: const TextStyle(fontSize: 28))),
            )).toList()),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _startRec() async {
    if (!await _recorder.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izinkan akses mikrofon dulu')));
      return;
    }
    final dir = await getTemporaryDirectory();
    _recPath = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: _recPath!);
    setState(() { _isRecording = true; _recSecs = 0; });
    _setRecording(true);
  }

  void _setRecording(bool v) {
    if (_myId.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$_myId').set({'isRecording': v}, SetOptions(merge: true));
  }

  Future<void> _stopRec({bool send = true}) async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    _setRecording(false);
    if (send && path != null) {
      final url = await CloudinaryService().uploadVoiceNote(File(path));
      if (url != null) _sendMessage(voiceUrl: url, voiceDuration: _recSecs);
    }
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
      return Scaffold(body: Center(child: Text('Pasangan belum terhubung', style: TextStyle(color: DyKalTheme.textGrey))));
    }
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: SafeArea(child: Column(children: [
        _header(),
        Expanded(child: _list()),
        if (_replyTo != null) _replyPreview(),
        if (_isRecording) _recordingBar(),
        _input(),
      ])),
    );
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
        ]),
      );

  Widget _list() => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats/$_coupleId/messages').orderBy('createdAt').snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off, size: 48, color: DyKalTheme.textGrey.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text('Gagal memuat chat', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Cek koneksi & pastikan Firestore rules sudah di-publish.', textAlign: TextAlign.center, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
            ])));
          }
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: DyKalTheme.primary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: DyKalTheme.textGrey.withOpacity(0.4)),
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
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p == null ? 'Gagal menyimpan' : 'Foto tersimpan ✅')));
                        } : null,
                      );
            },
          );
        },
      );

  Widget _replyPreview() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: DyKalTheme.primary, width: 3))),
        child: Row(children: [
          Icon(Icons.reply, size: 16, color: DyKalTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Membalas', style: TextStyle(fontSize: 11, color: DyKalTheme.primary, fontWeight: FontWeight.w700)), Text(_replyTo!.text.isEmpty ? 'Pesan' : _replyTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))])),
          IconButton(onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close, size: 16)),
        ]),
      );

  Widget _recordingBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Icon(Icons.fiber_manual_record, color: DyKalTheme.primary, size: 16),
          const SizedBox(width: 8),
          Text('Merekam...', style: TextStyle(color: DyKalTheme.primary, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(onTap: () => _stopRec(send: false), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete, color: Colors.red, size: 20))),
        ]),
      );

  Widget _input() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
        child: Row(children: [
          IconButton(onPressed: _pickImage, icon: Icon(Icons.image, color: DyKalTheme.primary, size: 22), tooltip: 'Kirim foto'),
          IconButton(onPressed: _pickSticker, icon: Icon(Icons.emoji_emotions_outlined, color: DyKalTheme.primary, size: 22), tooltip: 'Stiker'),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(24)),
            child: TextField(controller: _msgController, onChanged: _onChanged, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Tulis pesan...', border: InputBorder.none)),
          )),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _msgController,
            builder: (_, v, __) => v.text.trim().isNotEmpty
              ? GestureDetector(
                  onTap: () => _sendMessage(),
                  child: Container(width: 44, height: 44, decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)))
              : GestureDetector(
                  onTap: () => _isRecording ? _stopRec(send: true) : _startRec(),
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: _isRecording ? Colors.red : DyKalTheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(_isRecording ? Icons.send : Icons.mic, color: _isRecording ? Colors.white : DyKalTheme.primary, size: 20)),
                ),
          ),
        ]),
      );
}
