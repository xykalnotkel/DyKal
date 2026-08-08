import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, voice, viewOnce, system }
enum MessageStatus { sending, sent, delivered, read } // centang 1,2, dibaca

class ChatMessage {
  final String id;
  final String fromId;
  final String toId;
  final String text;
  final MessageType type;
  final String? imageUrl; // dari Cloudinary
  final String? voiceUrl;
  final int? voiceDuration; // detik
  final String? replyToId;
  final String? replyToText;
  final String? replyToName;
  final bool isEdited;
  final bool isDeleted;
  final bool isLoved; // Love kan pesan
  final bool isViewOnce;
  final bool viewOnceOpened;
  final MessageStatus status;
  final Timestamp createdAt;

  ChatMessage({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.text,
    this.type = MessageType.text,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    this.replyToId,
    this.replyToText,
    this.replyToName,
    this.isEdited = false,
    this.isDeleted = false,
    this.isLoved = false,
    this.isViewOnce = false,
    this.viewOnceOpened = false,
    this.status = MessageStatus.sent,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'fromId': fromId,
    'toId': toId,
    'text': text,
    'type': type.name,
    'imageUrl': imageUrl,
    'voiceUrl': voiceUrl,
    'voiceDuration': voiceDuration,
    'replyToId': replyToId,
    'replyToText': replyToText,
    'replyToName': replyToName,
    'isEdited': isEdited,
    'isDeleted': isDeleted,
    'isLoved': isLoved,
    'isViewOnce': isViewOnce,
    'viewOnceOpened': viewOnceOpened,
    'status': status.name,
    'createdAt': createdAt,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'],
    fromId: m['fromId'],
    toId: m['toId'],
    text: m['text'] ?? '',
    type: MessageType.values.firstWhere((e) => e.name == m['type'], orElse: () => MessageType.text),
    imageUrl: m['imageUrl'],
    voiceUrl: m['voiceUrl'],
    voiceDuration: m['voiceDuration'],
    replyToId: m['replyToId'],
    replyToText: m['replyToText'],
    replyToName: m['replyToName'],
    isEdited: m['isEdited'] ?? false,
    isDeleted: m['isDeleted'] ?? false,
    isLoved: m['isLoved'] ?? false,
    isViewOnce: m['isViewOnce'] ?? false,
    viewOnceOpened: m['viewOnceOpened'] ?? false,
    status: MessageStatus.values.firstWhere((e) => e.name == m['status'], orElse: () => MessageStatus.sent),
    createdAt: m['createdAt'] ?? Timestamp.now(),
  );
}

// Untuk indikator Realtime: typing, recording, online
class UserPresence {
  final String uid;
  final bool isOnline;
  final bool isTyping;
  final bool isRecording;
  final Timestamp lastSeen;

  UserPresence({required this.uid, required this.isOnline, required this.isTyping, required this.isRecording, required this.lastSeen});
  
  Map<String, dynamic> toMap() => {
    'isOnline': isOnline,
    'isTyping': isTyping,
    'isRecording': isRecording,
    'lastSeen': lastSeen,
  };
}
