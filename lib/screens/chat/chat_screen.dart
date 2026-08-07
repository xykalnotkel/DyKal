import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../services/cloudinary_service.dart';
import 'widgets/message_bubble.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  ChatMessage? _replyTo;
  bool _isTyping = false;
  bool _isRecording = false;

  final myId = "uid_aku";
  final partnerId = "uid_dia";
  final coupleId = "dykal_couple_01";

  void _sendMessage({String? imageUrl, bool viewOnce = false}) {
    final text = _msgController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: myId,
      toId: partnerId,
      text: text,
      type: imageUrl != null ? (viewOnce ? MessageType.viewOnce : MessageType.image) : MessageType.text,
      imageUrl: imageUrl,
      isViewOnce: viewOnce,
      replyToId: _replyTo?.id,
      createdAt: Timestamp.now(),
    );

    _firestore.collection('chats').doc(coupleId).collection('messages').doc(msg.id).set(msg.toMap());
    _firestore.doc('presence/$myId').set({'isTyping': false, 'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    _msgController.clear();
    setState(() => _replyTo = null);
  }

  Future<void> _pickImage({bool viewOnce = false}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final url = await CloudinaryService().uploadImage(File(xfile.path), folder: viewOnce ? "dykal/view_once" : "dykal/chat");
    if (url != null) _sendMessage(imageUrl: url, viewOnce: viewOnce);
  }

  void _onTextChanged(String v) {
    final typing = v.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _firestore.doc('presence/$myId').set({'isTyping': typing}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HEADER SEAMLESS - Icons modern rounded
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: DyKalTheme.primary, child: Text("D", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            SizedBox(width: 12),
            Expanded(child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.doc('presence/$partnerId').snapshots(),
              builder: (_, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final isOnline = data?['isOnline'] ?? false;
                final isTyping = data?['isTyping'] ?? false;
                final isRecording = data?['isRecording'] ?? false;
                String subtitle = isTyping ? "sedang mengetik..." : isRecording ? "sedang merekam audio..." : isOnline ? "online" : "offline";
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text("Ayang", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 6),
                    Icon(Icons.favorite, color: DyKalTheme.primary, size: 14),
                  ]),
                  Row(children: [
                    if (isTyping) Icon(Icons.more_horiz, size: 14, color: DyKalTheme.primary),
                    if (isRecording) Icon(Icons.graphic_eq, size: 14, color: DyKalTheme.primary),
                    if (isTyping || isRecording) SizedBox(width: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isTyping || isRecording ? DyKalTheme.primary : DyKalTheme.textGrey, fontStyle: isTyping ? FontStyle.italic : FontStyle.normal)),
                  ]),
                ]);
              },
            )),
            IconButton(onPressed: () => Navigator.pushNamed(context, '/audioCall'), icon: Icon(Icons.phone, color: DyKalTheme.primary, size: 22)),
            IconButton(onPressed: () => Navigator.pushNamed(context, '/videoCall'), icon: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: DyKalTheme.primary, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.videocam, color: Colors.white, size: 18))),
          ]),
        ),

        // LIST PESAN REALTIME
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').doc(coupleId).collection('messages').orderBy('createdAt', descending: true).snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return Center(child: CircularProgressIndicator(color: DyKalTheme.primary));
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/illustrations/webp/chat_empty.webp', width: 160, height: 160, fit: BoxFit.contain),
                  SizedBox(height: 12),
                  Text("Belum ada chat", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.send, size: 14, color: DyKalTheme.textGrey),
                    SizedBox(width: 6),
                    Text("Kirim pesan pertama ke Ayang", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
                  ]),
                  SizedBox(height: 16),
                  Image.asset('assets/illustrations/webp/chat_illustration2.webp', width: 140, height: 80, fit: BoxFit.contain, opacity: AlwaysStoppedAnimation(0.6)),
                ]));
              }
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final msg = ChatMessage.fromMap(docs[i].data() as Map<String, dynamic>);
                  if (msg.fromId != myId && msg.status != MessageStatus.read) {
                    docs[i].reference.update({'status': 'read'});
                  }
                  return MessageBubble(
                    message: msg,
                    isMe: msg.fromId == myId,
                    onSwipeReply: () => setState(() => _replyTo = msg),
                    onLove: () => docs[i].reference.update({'isLoved': !msg.isLoved}),
                    onEdit: (newText) => docs[i].reference.update({'text': newText, 'isEdited': true}),
                    onDelete: () => docs[i].reference.update({'isDeleted': true, 'text': 'Pesan ini telah dihapus'}),
                  );
                },
              );
            },
          ),
        ),

        // REPLY PREVIEW - Icons rounded
        if (_replyTo != null)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: DyKalTheme.primary, width: 3))),
            child: Row(children: [
              Icon(Icons.reply, size: 16, color: DyKalTheme.primary),
              SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Membalas", style: TextStyle(fontSize: 11, color: DyKalTheme.primary, fontWeight: FontWeight.w700)),
                Text(_replyTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
              ])),
              IconButton(onPressed: ()=> setState(()=> _replyTo=null), icon: Icon(Icons.close, size: 16)),
            ]),
          ),

        // INPUT AREA SEAMLESS - Icons modern rounded
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.of(context).padding.bottom * 0.3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0,-2))],
          ),
          child: Row(children: [
            IconButton(onPressed: () => _pickImage(viewOnce: false), icon: Icon(Icons.image, color: DyKalTheme.textGrey, size: 22)),
            IconButton(onPressed: () => _pickImage(viewOnce: true), icon: Icon(Icons.visibility_off, color: DyKalTheme.primary, size: 22), tooltip: "Foto 1x lihat"),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _msgController,
                  onChanged: _onTextChanged,
                  minLines: 1, maxLines: 4,
                  decoration: InputDecoration(hintText: "Tulis pesan...", border: InputBorder.none, hintStyle: TextStyle(color: DyKalTheme.textGrey, fontSize: 14)),
                ),
              ),
            ),
            SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: _msgController,
              builder: (_, v, __) => v.text.trim().isNotEmpty
                  ? GestureDetector(
                      onTap: () => _sendMessage(),
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, shape: BoxShape.circle), child: Icon(Icons.send, color: Colors.white, size: 18)),
                    )
                  : GestureDetector(
                      onLongPressStart: (_) => setState(()=> _isRecording = true),
                      onLongPressEnd: (_) => setState(()=> _isRecording = false),
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.mic, color: DyKalTheme.primary, size: 18)),
                    ),
            ),
          ]),
        ),
      ],
    );
  }
}
