import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// FCM Service DyKal — Gratis Spark (Tanpa Cloud Functions)
/// Karena Spark tidak bisa pakai Cloud Functions untuk kirim push otomatis,
/// kita pakai strategi 2 lapis:
/// 1. FCM Token disimpan di users/{uid}.fcmToken → bisa dipakai kirim manual via Firebase Console
/// 2. Realtime fallback: setiap chat baru di Firestore → listener di app yang background/foreground akan trigger local notification (jadi tetap ada notif walau tanpa server push)
/// Untuk push saat app killed (100% reliable) butuh Blaze + Functions, tapi 95% kasus local listener sudah cukup untuk 2 orang.
class FCMService {
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  Future<void> init() async {
    // 1. Request permission (Android 13+ & iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Init local notifications (untuk fallback)
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    await _local.initialize(InitializationSettings(android: android, iOS: ios));

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
    final notif = msg.notification;
    if (notif == null) return;
    // Tampilkan sebagai local notification biar ada heads-up
    const androidDetails = AndroidNotificationDetails(
      'dykal_chat',
      'DyKal Chat',
      channelDescription: 'Notifikasi chat & surat',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: Color(0xFFFF6B8A),
    );
    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: androidDetails),
    );
  }

  void _handleTap(RemoteMessage msg) {
    // Navigasi ke chat jika data.type == chat
    final type = msg.data['type'];
    if (type == 'chat') {
      // Navigator.pushNamed(context, '/chat')
      print('Tapped chat notif: ${msg.data}');
    }
  }

  /// Fallback Realtime → Local Notification (tanpa server)
  /// Panggil ini di MainNav initState setelah login:
  /// FCMService().listenChatForLocalNotif(coupleId)
  void listenChatForLocalNotif(String coupleId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _db.collection('chats').doc(coupleId).collection('messages')
      .orderBy('createdAt', descending: true).limit(1)
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
        _showLocalChatNotif(data['fromName'] ?? 'Ayang', text);
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
