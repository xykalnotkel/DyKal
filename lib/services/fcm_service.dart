import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

/// FCM Service DyKal — Gratis Spark (Tanpa Cloud Functions)
/// Karena Spark tidak bisa pakai Cloud Functions untuk kirim push otomatis,
/// kita pakai strategi 2 lapis:
/// 1. FCM Token disimpan di users/{uid}.fcmToken → bisa dipakai kirim manual via Firebase Console
/// 2. Realtime fallback: setiap chat baru di Firestore → listener di app yang background/foreground akan trigger local notification (jadi tetap ada notif walau tanpa server push)
/// Untuk push saat app killed (100% reliable) butuh Blaze + Functions, tapi 95% kasus local listener sudah cukup untuk 2 orang.
class FCMService {
  static final FCMService _i = FCMService._();
  FCMService._();
  factory FCMService() => _i;
  bool _initialized = false;
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;
  static GlobalKey<NavigatorState>? navKey; // di-set dari main.dart -> navigasi dari aksi notif
  String? _callType;     // 'audio'/'video' notif call terakhir
  String? _callCoupleId;

  /// Dipanggil dari AuthGate setelah login (idempoten)
  void ensureInit() {
    if (_initialized) return;
    _initialized = true;
    init();
  }

  Future<void> init() async {
    // 1. Request permission (Android 13+ & iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Init local notifications (untuk fallback) + handler aksi (balas dari notif)
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotifResponse,
    );

    // FIX #1: channel panggilan (high priority + fullScreenIntent + badge + sound)
    const callChannel = AndroidNotificationChannel(
      'dykal_call', 'Panggilan DyKal',
      description: 'Notifikasi panggilan masuk',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(callChannel);

    // FIX FCM: channel CHAT dibuat explicit (biar notif pas app killed muncul) + request POST_NOTIFICATIONS runtime (Android 13+)
    const chatChannel = AndroidNotificationChannel('dykal_chat', 'DyKal Chat', description: 'Notifikasi chat, surat & media', importance: Importance.high, playSound: true, showBadge: true);
    final _loc = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (_loc != null) {
      await _loc.createNotificationChannel(chatChannel);
      await _loc.requestNotificationsPermission();
    }

    // 3. Dapatkan & simpan token
    await _saveToken();
    _messaging.onTokenRefresh.listen((token) => _saveToken(token: token));

    // 4. Handler FCM saat foreground (app dibuka)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Tap notif saat background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 6. Subscribe ke topic couple (opsional, untuk broadcast ke pasangan)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await _db.doc('users/$uid').get();
      final coupleId = userDoc.data()?['coupleId'];
      if (coupleId != null) {
        await _messaging.subscribeToTopic(coupleId);
      }
    }
  }

  Future<void> _saveToken({String? token}) async {
    try {
      token ??= await _messaging.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await _db.doc('users/$uid').set({'fcmToken': token}, SetOptions(merge: true));
        // Juga simpan di presence biar gampang debug
        await _db.doc('presence/$uid').set({'fcmToken': token}, SetOptions(merge: true));
      }
      print('FCM Token: $token');
    } catch (e) {
      print('FCM token error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage msg) async {
    // FIX #1: panggilan -> notif khusus (accept/decline + fullScreenIntent + nama)
    if (msg.data['type'] == 'call') { _handleCallMessage(msg); return; }
    final notif = msg.notification;
    if (notif == null) return;
    final androidDetails = AndroidNotificationDetails(
      'dykal_chat',
      'DyKal Chat',
      channelDescription: 'Notifikasi chat & surat',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: const Color(0xFFFF6B8A),
      actions: [
        AndroidNotificationAction('reply', 'Balas', inputs: [AndroidNotificationActionInput(label: 'Ketik balasan...')], showsUserInterface: false, cancelNotification: false),
        AndroidNotificationAction('mark_read', 'Tanda Dibaca', showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('mute', 'Bisukan', showsUserInterface: false, cancelNotification: true),
      ],
    );
    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: androidDetails),
    );
  }

  void _handleCallMessage(RemoteMessage msg) async {
    final callerName = msg.data['callerName'] ?? msg.notification?.title ?? 'DyKal';
    final callType = msg.data['callType'] ?? 'video';
    _callType = callType;
    _callCoupleId = msg.data['coupleId'];
    final androidDetails = AndroidNotificationDetails(
      'dykal_call', 'Panggilan DyKal',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      actions: [
        AndroidNotificationAction('decline_call', 'Tolak', showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('accept_call', 'Angkat', showsUserInterface: true, cancelNotification: true),
      ],
    );
    await _local.show(
      7777,
      '📞 $callerName',
      callType == 'video' ? 'Panggilan video masuk' : 'Panggilan suara masuk',
      NotificationDetails(android: androidDetails),
      payload: callType,
    );
  }

  /// Handler aksi notifikasi (Quick Reply dari notif)
  Future<void> _onNotifResponse(NotificationResponse r) async {
    if (r.actionId == 'reply' && r.input != null && r.input!.trim().isNotEmpty) {
      await _sendReply(r.input!.trim());
    } else if (r.actionId == 'accept_call') {
      _acceptCall(r.payload ?? _callType ?? 'video');
    } else if (r.actionId == 'decline_call') {
      await _declineCall();
    } else if (r.actionId == 'mark_read') {
      await _markChatRead();
    } else if (r.actionId == 'mute') {
      await _muteChat();
    }
  }

  Future<void> _markChatRead() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final coupleId = AuthService().coupleId ?? '';
      if (coupleId.isEmpty) return;
      final qs = await _db.collection('chats/$coupleId/messages').where('fromId', isNotEqualTo: uid).get();
      for (final d in qs.docs) {
        if ((d.data()['status'] ?? '') != 'read') await d.reference.update({'status': 'read'});
      }
    } catch (_) {}
  }

  Future<void> _muteChat() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _db.doc('users/$uid').set({'notifPrefs': {'chat': false}}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _acceptCall(String callType) {
    _local.cancel(7777);
    final route = callType == 'audio' ? '/audioCall' : '/videoCall';
    navKey?.currentState?.pushNamed(route, arguments: {'isCaller': false, 'type': callType});
  }

  Future<void> _declineCall() async {
    _local.cancel(7777);
    final coupleId = AuthService().coupleId ?? _callCoupleId ?? '';
    if (coupleId.isNotEmpty) {
      try { await _db.doc('calls/$coupleId').update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()}); } catch (_) {}
    }
  }

  Future<void> _sendReply(String text) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final meSnap = await _db.doc('users/$uid').get();
      final coupleId = meSnap.data()?['coupleId'] as String?;
      if (coupleId == null) return;
      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      await _db.collection('chats/$coupleId/messages').doc(msgId).set({
        'id': msgId,
        'fromId': uid,
        'toId': '',
        'text': text,
        'type': 'text',
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _handleTap(RemoteMessage msg) {
    // FIX #1: tap notif -> buka layar sesuai jenis (call -> incoming call, chat -> chat)
    final type = msg.data['type'];
    if (type == 'call') {
      final callType = msg.data['callType'] ?? 'video';
      navKey?.currentState?.pushNamed('/incomingCall', arguments: callType);
    } else if (type == 'chat') {
      navKey?.currentState?.pushNamed('/chat');
    }
  }

  /// Fallback Realtime → Local Notification (tanpa server)
  /// Panggil ini di MainNav initState setelah login:
  /// FCMService().listenChatForLocalNotif(coupleId)
  void listenChatForLocalNotif(String coupleId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _db.collection('chats').doc(coupleId).collection('messages')
      .limit(1)
      .snapshots()
      .listen((snap) {
        if (snap.docs.isEmpty) return;
        final doc = snap.docs.first;
        final data = doc.data();
        final fromId = data['fromId'];
        // Jangan notif pesan sendiri
        if (fromId == myUid) return;
        // Cek apakah app sedang di chat screen? bisa skip
        // Tampilkan local notif
        final text = data['text'] ?? (data['imageUrl'] != null ? 'Foto' : 'Pesan baru');
        _showLocalChatNotif(data['fromName'] ?? '', text);
      });
  }

  Future<void> _showLocalChatNotif(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'dykal_chat_realtime',
      'DyKal Realtime',
      channelDescription: 'Notifikasi realtime lokal',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFFFF6B8A),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  // Top-level handler untuk background (harus di luar class, daftarkan di main.dart)
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Background FCM: ${message.messageId}');
  }
}
