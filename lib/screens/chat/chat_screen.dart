import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
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

  void _sendMessage({String? imageUrl, bool viewOnce = false, String? voiceUrl, int? voiceDuration}) {
    final text = _msgController.text.trim();
    if (text.isEmpty && imageUrl == null && voiceUrl == null) return;
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: _myId,
      toId: _partnerId,
      text: voiceUrl != null ? '' : text,
      type: voiceUrl != null ? MessageType.voice : (imageUrl != null ? (viewOnce ? MessageType.viewOnce : MessageType.image) : MessageType.text),
      imageUrl: imageUrl,
      voiceUrl: voiceUrl,
      voiceDuration: voiceDuration,
      replyToId: _replyTo?.id,
      createdAt: Timestamp.now(),
    );
    FirebaseFirestore.instance.collection('chats/$_coupleId/messages').doc(msg.id).set(msg.toMap());
    _msgController.clear();
    setState(() { _replyTo = null; _isTyping = false; });
    _setTyping(false);
  }

  Future<void> _pickImage({bool viewOnce = false}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final url = await CloudinaryService().uploadImage(File(xfile.path), folder: viewOnce ? "dykal/view_once" : "dykal/chat");
    if (url != null) _sendMessage(imageUrl: url, viewOnce: viewOnce);
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
          CircleAvatar(radius: 20, backgroundColor: DyKalTheme.primary, child: Text(_partnerName.isNotEmpty ? _partnerName[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
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
                Text(sub, style: TextStyle(fontSize: 12, color: (typing || rec) ? DyKalTheme.primary : DyKalTheme.textGrey)),
              ]);
            },
          )),
          IconButton(onPressed: () => Navigator.pushNamed(context, '/audioCall', arguments: {'isCaller': true, 'type': 'audio'}), icon: Icon(Icons.phone, color: DyKalTheme.primary, size: 22)),
          IconButton(onPressed: () => Navigator.pushNamed(context, '/videoCall', arguments: {'isCaller': true, 'type': 'video'}), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: DyKalTheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.videocam, color: Colors.white, size: 18))),
        ]),
      );

  Widget _list() => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats/$_coupleId/messages').orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: DyKalTheme.primary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: DyKalTheme.textGrey.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('Belum ada chat', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Kirim pesan pertama ke $_partnerName', style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
          ]));
          return ListView.builder(
            controller: _scrollController, reverse: true,
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
          IconButton(onPressed: () => _pickImage(viewOnce: false), icon: Icon(Icons.image, color: DyKalTheme.textGrey, size: 22)),
          IconButton(onPressed: () => _pickImage(viewOnce: true), icon: Icon(Icons.visibility_off, color: DyKalTheme.primary, size: 22), tooltip: 'Foto 1x lihat'),
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
                  onLongPressStart: (_) => _startRec(),
                  onLongPressEnd: (_) => _stopRec(send: true),
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: _isRecording ? Colors.red : DyKalTheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.mic, color: _isRecording ? Colors.white : DyKalTheme.primary, size: 20)),
                ),
          ),
        ]),
      );
}
