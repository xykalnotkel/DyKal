import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../screens/call/incoming_call_screen.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'ringtone_player.dart';

/// ===== Handler ISOLATE LATAR (app killed) untuk AKSI notifikasi lokal =====
/// Wajib top-level + pragma. Berjalan tanpa UI: semua aksi menulis langsung
/// ke Firestore (balas pesan, tandai dibaca, bisukan, tolak panggilan).
@pragma('vm:entry-point')
Future<void> dykalNotifBackgroundResponse(NotificationResponse r) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    return; // tanpa Firebase tak ada yang bisa dilakukan di background
  }
  Map<String, dynamic> p = {};
  try {
    final raw = r.payload;
    if (raw != null && raw.startsWith('{')) p = Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {}
  final cid = (p['cid'] ?? '') as String;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final db = FirebaseFirestore.instance;
  final local = FlutterLocalNotificationsPlugin();
  try {
    await local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification')));
  } catch (_) {}

  try {
    switch (r.actionId) {
      case 'reply':
        final text = (r.input ?? '').trim();
        if (text.isEmpty || cid.isEmpty || uid.isEmpty) break;
        final msgId = DateTime.now().millisecondsSinceEpoch.toString();
        await db.collection('chats/$cid/messages').doc(msgId).set({
          'id': msgId,
          'fromId': uid,
          'toId': '',
          'text': text,
          'type': 'text',
          'status': 'sent',
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Ganti isi notif jadi konfirmasi kecil (aksi sudah terkirim).
        await local.show(770012, 'Terkirim', text,
            const NotificationDetails(
                android: AndroidNotificationDetails('dykal_chat', 'DyKal Chat',
                    importance: Importance.low, priority: Priority.low)));
        break;
      case 'mark_read':
        if (cid.isEmpty || uid.isEmpty) break;
        final qs = await db.collection('chats/$cid/messages').where('fromId', isNotEqualTo: uid).get();
        for (final d in qs.docs) {
          if ((d.data()['status'] ?? '') != 'read') await d.reference.update({'status': 'read'});
        }
        break;
      case 'mute':
        if (uid.isEmpty) break;
        await db.doc('users/$uid').set({'notifPrefs': {'chat': false}}, SetOptions(merge: true));
        break;
      case 'decline_call':
        if (cid.isNotEmpty) {
          await db.doc('calls/$cid').update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
        }
        await local.cancel(7777);
        break;
      case 'accept_call':
        // showsUserInterface: true -> seharusnya masuk jalur foreground saat
        // app terbuka. Kalau ternyata sampai di sini, abaikan (app akan
        // terbuka & mendeteksi panggilan lewat listener Firestore).
        break;
    }
  } catch (_) {}
}

/// BATCH I: tandai semua pesan 'sent' dari partner -> 'delivered', SEKALI JALAN.
/// Di-spark dari background FCM handler (pesan sampai walau app mati = centang
/// 2 per permintaan owner) dan dari MainNav saat app dibuka.
Future<void> markDeliveredFirestore(FirebaseFirestore db, String cid, String uid) async {
  if (cid.isEmpty || uid.isEmpty) return;
  try {
    final qs = await db
        .collection('chats/$cid/messages')
        .where('status', isEqualTo: 'sent')
        .limit(60)
        .get();
    final batch = db.batch();
    var n = 0;
    for (final d in qs.docs) {
      if (d.data()['fromId'] != uid) {
        batch.update(d.reference, {'status': 'delivered'});
        n++;
      }
    }
    if (n > 0) await batch.commit();
  } catch (_) {}
}

/// FCM Service DyKal — Gratis Spark (Tanpa Cloud Functions).
///
/// ARSITEKTUR NOTIF (Batch G, spek v2 #4):
/// - Worker mengirim DATA-ONLY ke device ber-notifCap 'v2' (tidak ada key
///   notification) -> app yang merender notif di SEMUA state (foreground via
///   onMessage, killed via firebaseMessagingBackgroundHandler) lengkap dengan
///   MessagingStyle avatar + aksi Balas / Tandai / Bisukan / Angkat / Tolak.
/// - Device app lama tetap menerima payload hybrid (worker menyertakan key
///   notification) supaya notif latar belakang mereka tidak hilang.
class FCMService {
  static final FCMService _i = FCMService._();
  FCMService._();
  factory FCMService() => _i;
  bool _initialized = false;
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;
  static GlobalKey<NavigatorState>? navKey; // di-set dari main.dart -> navigasi dari aksi notif
  /// Callback unduh update dari aksi notif — diisi main.dart
  /// (memutus siklus import update_service <-> fcm_service).
  static Future<void> Function()? onUpdateDownload;
  String? _callType;     // 'audio'/'video' notif call terakhir
  String? _callCoupleId;
  bool _localReady = false; // plugin lokal siap dipakai (setelah init)
  DateTime? _lastChatFcmAt; // dedupe fallback realtime vs push FCM (3 dtk)

  static const int notifIdCall = 7777;
  static const int notifIdChat = 770011;

  /// Dipanggil dari AuthGate setelah login (idempoten)
  void ensureInit() {
    if (_initialized) return;
    _initialized = true;
    init();
  }

  Future<void> init() async {
    // 1. Request permission (Android 13+ & iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Init local notifications + handler aksi (foreground & BACKGROUND).
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotifResponse,
      // Aksi tanpa UI (Balas/Tandai/Bisukan/Tolak) saat app KILLED masuk ke
      // handler isolate ini — wajib agar quick-reply benar-benar terkirim.
      onDidReceiveBackgroundNotificationResponse: dykalNotifBackgroundResponse,
    );
    _localReady = true;

    // CHANNEL LENGKAP. PENTING: nama/level channel Android DIKUNCI saat
    // pertama dibuat — channel lama dipertahankan demi worker hybrid;
    // channel *_v2 memakai NADA DERING TELPON SISTEM (spek v2 #5A), karena
    // suara channel lama tak bisa diubah setelah tercipta.
    final loc = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (loc != null) {
      const ringtone = UriAndroidNotificationSound('content://settings/system/ringtone');
      const channels = <AndroidNotificationChannel>[
        AndroidNotificationChannel('dykal_call', 'Panggilan DyKal', description: 'Panggilan masuk (kompat lama)', importance: Importance.max, playSound: true, enableVibration: true, showBadge: true),
        AndroidNotificationChannel('dykal_call_audio', 'Panggilan Suara DyKal', description: 'Panggilan suara masuk', importance: Importance.max, playSound: true, enableVibration: true, showBadge: true),
        AndroidNotificationChannel('dykal_call_video', 'Panggilan Video DyKal', description: 'Panggilan video masuk', importance: Importance.max, playSound: true, enableVibration: true, showBadge: true),
        AndroidNotificationChannel('dykal_call_audio_v2', 'Panggilan Suara DyKal', description: 'Panggilan suara masuk (dering telepon)', importance: Importance.max, sound: ringtone, enableVibration: true, showBadge: true),
        AndroidNotificationChannel('dykal_call_video_v2', 'Panggilan Video DyKal', description: 'Panggilan video masuk (dering telepon)', importance: Importance.max, sound: ringtone, enableVibration: true, showBadge: true),
        AndroidNotificationChannel('dykal_chat', 'DyKal Chat', description: 'Notifikasi chat, surat & media', importance: Importance.high, playSound: true, showBadge: true),
        AndroidNotificationChannel('dykal_chat_realtime', 'DyKal Realtime', description: 'Notifikasi realtime lokal (mode hemat)', importance: Importance.high, playSound: true, showBadge: true),
        AndroidNotificationChannel('dykal_birthday', 'DyKal Moment', description: 'Pengingat ultah & anniversary', importance: Importance.high, playSound: true, showBadge: true),
        AndroidNotificationChannel('dykal_update', 'Info Update DyKal', description: 'Versi & pembaruan aplikasi terbaru', importance: Importance.high, playSound: true, showBadge: true),
      ];
      for (final ch in channels) {
        await loc.createNotificationChannel(ch);
      }
      await loc.requestNotificationsPermission();
      // Izin FULL SCREEN INTENT (Android 14+ minta terpisah) — kunci agar
      // panggilan masuk bisa tampil sebagai layar dering penuh.
      try { await loc.requestFullScreenIntentPermission(); } catch (_) {}
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
    // TOPIC 'app_updates' — CI membroadcast push ke topic ini setiap rilis.
    try { await _messaging.subscribeToTopic('app_updates'); } catch (_) {}
  }

  Future<void> _saveToken({String? token}) async {
    try {
      token ??= await _messaging.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await _db.doc('users/$uid').set({
          'fcmToken': token,
          // BATCH G: klaim kemampuan render notif kaya (data-only) — pengirim
          // membaca flag ini sebelum memutuskan payload dataOnly ke worker.
          'notifCap': 'v2',
          'appVer': '1.3.0',
        }, SetOptions(merge: true));
        await _db.doc('presence/$uid').set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Helper render bersama (dipakai foreground & isolate latar)
  // ------------------------------------------------------------------

  /// Unduh avatar sekali -> byte mentah (dipakai dua varian ikon di bawah).
  static Future<Uint8List?> _avatarBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        return Uint8List.fromList(r.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  /// Untuk `largeIcon`: hierarki AndroidBitmap.
  /// Untuk `Person.icon`: hierarki AndroidIcon (lihat _avatarIcon).
  /// Keduanya BEDA hierarki di FLN 19 — mencampurnya = argument_type_not_assignable.
  static Future<ByteArrayAndroidBitmap?> _avatarBmp(String? url) async {
    final b = await _avatarBytes(url);
    return b == null ? null : ByteArrayAndroidBitmap(b);
  }

  /// Untuk `Person.icon`: hierarki AndroidIcon (ByteArrayAndroidIcon).
  static Future<ByteArrayAndroidIcon?> _avatarIcon(String? url) async {
    final b = await _avatarBytes(url);
    return b == null ? null : ByteArrayAndroidIcon(b);
  }

  /// Notif CHAT/SURAT ala WhatsApp: MessagingStyle + avatar + aksi.
  static Future<void> showRichChatNotif(
    FlutterLocalNotificationsPlugin plugin, {
    required String title,
    required String body,
    String? avatarUrl,
    String coupleId = '',
    String channelId = 'dykal_chat',
    String channelName = 'DyKal Chat',
  }) async {
    final avatar = await _avatarBmp(avatarUrl);       // largeIcon (AndroidBitmap)
    final avatarIco = await _avatarIcon(avatarUrl);   // Person.icon (AndroidIcon)
    final me = const Person(name: 'Saya', key: 'dykal_me');
    final partner = Person(name: title, key: 'dykal_partner', icon: avatarIco);
    final style = MessagingStyleInformation(
      me,
      conversationTitle: title,
      messages: [Message(body, DateTime.now(), partner)],
    );
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifikasi chat & surat',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: const Color(0xFFFF6B8A),
      styleInformation: style,
      largeIcon: avatar,
      actions: [
        AndroidNotificationAction('reply', 'Balas', inputs: [AndroidNotificationActionInput(label: 'Ketik balasan...')], cancelNotification: false),
        AndroidNotificationAction('mark_read', 'Tanda Dibaca', cancelNotification: true),
        AndroidNotificationAction('mute', 'Bisukan', cancelNotification: true),
      ],
    );
    await plugin.show(notifIdChat, title, body, NotificationDetails(android: androidDetails),
        payload: jsonEncode({'t': 'chat', 'cid': coupleId}));
  }

  /// Tandai delivered sekali jalan (dipanggil MainNav).
  static Future<void> markDeliveredNow(String cid) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return markDeliveredFirestore(FirebaseFirestore.instance, cid, uid);
  }

  /// Notif PANGGILAN layar penuh (dering telepon sistem + Angkat/Tolak).
  static Future<void> showRichCallNotif(
    FlutterLocalNotificationsPlugin plugin,
    Map<String, dynamic> data,
  ) async {
    final callerName = (data['callerName'] as String?)?.isNotEmpty == true
        ? data['callerName'] as String
        : ((data['senderName'] as String?)?.isNotEmpty == true ? data['senderName'] as String : 'Pasangan');
    final callType = (data['callType'] as String?) ?? 'video';
    final cid = (data['coupleId'] as String?) ?? '';
    final avatar = await _avatarBmp(data['callerAvatar'] as String? ?? data['senderAvatar'] as String?);
    final channelId = callType == 'audio' ? 'dykal_call_audio_v2' : 'dykal_call_video_v2';
    final channelName = callType == 'audio' ? 'Panggilan Suara DyKal' : 'Panggilan Video DyKal';
    final androidDetails = AndroidNotificationDetails(
      channelId, channelName,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      color: const Color(0xFFFF6B8A),
      largeIcon: avatar,
      actions: [
        AndroidNotificationAction('decline_call', 'Tolak', cancelNotification: true),
        AndroidNotificationAction('accept_call', 'Angkat', showsUserInterface: true, cancelNotification: true),
      ],
    );
    await plugin.show(
      notifIdCall,
      callerName,
      callType == 'video' ? 'Panggilan video masuk' : 'Panggilan suara masuk',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({'t': 'call', 'cid': cid, 'ct': callType}),
    );
  }

  // ------------------------------------------------------------------
  // Pesan masuk
  // ------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage msg) async {
    final data = msg.data;
    final type = data['type'] ?? '';
    // BATCH G: sinyal caller membatalkan panggilan -> matikan dering + notif.
    if (type == 'call_cancel') {
      try { await _local.cancel(notifIdCall); } catch (_) {}
      try { await RingtonePlayer.stop(); } catch (_) {}
      return;
    }
    if (type == 'call') {
      _handleCallMessage(msg);
      return;
    }
    // Push update realtime dari CI (topic app_updates).
    if (type == 'update') {
      final title = msg.notification?.title ?? 'DyKal versi terbaru';
      final body = msg.notification?.body ?? 'Ada pembaruan baru. Sentuh untuk mengunduh.';
      await showUpdateNotif(title, body: body);
      return;
    }
    if (!_localReady) return;
    _lastChatFcmAt = DateTime.now();
    final notif = msg.notification;
    final title = (data['senderName'] as String?)?.isNotEmpty == true
        ? data['senderName'] as String
        : (notif?.title ?? 'DyKal');
    final body = (data['messageBody'] as String?)?.isNotEmpty == true
        ? data['messageBody'] as String
        : (notif?.body ?? 'Pesan baru');
    unawaited(RingtonePlayer.playNotif());
    await showRichChatNotif(
      _local,
      title: title,
      body: body,
      avatarUrl: data['senderAvatar'] as String?,
      coupleId: (data['coupleId'] as String?) ?? '',
    );
  }

  void _handleCallMessage(RemoteMessage msg) async {
    final callType = msg.data['callType'] ?? 'video';
    _callType = callType;
    _callCoupleId = msg.data['coupleId'];
    if (!_localReady) return;
    if (DyKalCallService.inCall.value || IncomingCallScreen.isShowing) return;
    await showRichCallNotif(_local, msg.data);
  }

  /// Handler aksi notifikasi saat app HIDUP (foreground route).
  Future<void> _onNotifResponse(NotificationResponse r) async {
    switch (r.actionId) {
      case 'reply':
        final text = (r.input ?? '').trim();
        if (text.isNotEmpty) await _sendReply(text, _payloadCid(r));
        break;
      case 'accept_call':
        _acceptCall(_payloadCallType(r) ?? _callType ?? 'video');
        break;
      case 'decline_call':
        await _declineCall(_payloadCid(r));
        break;
      case 'mark_read':
        await _markChatRead(_payloadCid(r));
        break;
      case 'mute':
        await _muteChat();
        break;
      case 'download_update':
        final cb = onUpdateDownload;
        if (cb != null) await cb();
        break;
      default:
        // TAP BODY (tanpa aksi) -> buka layar sesuai payload.
        _routeBodyTap(r);
    }
  }

  String _payloadCid(NotificationResponse r) {
    try {
      final raw = r.payload ?? '';
      if (raw.startsWith('{')) return (jsonDecode(raw)['cid'] ?? '') as String;
    } catch (_) {}
    return '';
  }

  String? _payloadCallType(NotificationResponse r) {
    try {
      final raw = r.payload ?? '';
      if (raw.startsWith('{')) return jsonDecode(raw)['ct'] as String?;
      if (raw == 'audio' || raw == 'video') return raw; // payload lama polos
    } catch (_) {}
    return null;
  }

  void _routeBodyTap(NotificationResponse r) {
    final raw = r.payload ?? '';
    if (raw == 'update') {
      final cb = onUpdateDownload;
      if (cb != null) cb();
      return;
    }
    try {
      if (!raw.startsWith('{')) return;
      final p = jsonDecode(raw) as Map<String, dynamic>;
      final t = p['t'];
      if (t == 'chat') {
        navKey?.currentState?.pushNamed('/chat');
      } else if (t == 'call') {
        // Kalau layar incoming sudah tampil, jangan ditumpuk.
        if (IncomingCallScreen.isShowing) return;
        navKey?.currentState?.pushNamed('/incomingCall', arguments: (p['ct'] as String?) ?? 'video');
      }
    } catch (_) {}
  }

  Future<void> _markChatRead([String cid = '']) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final coupleId = cid.isNotEmpty ? cid : (AuthService().coupleId ?? '');
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
    _local.cancel(notifIdCall);
    if (IncomingCallScreen.isShowing) return; // layar incoming menanganinya
    final route = callType == 'audio' ? '/audioCall' : '/videoCall';
    navKey?.currentState?.pushNamed(route, arguments: {'isCaller': false, 'type': callType});
  }

  Future<void> _declineCall([String cid = '']) async {
    _local.cancel(notifIdCall);
    final coupleId = cid.isNotEmpty ? cid : (AuthService().coupleId ?? _callCoupleId ?? '');
    if (coupleId.isNotEmpty) {
      try { await _db.doc('calls/$coupleId').update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()}); } catch (_) {}
    }
  }

  Future<void> _sendReply(String text, [String cid = '']) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      String coupleId = cid;
      if (coupleId.isEmpty) {
        final meSnap = await _db.doc('users/$uid').get();
        coupleId = meSnap.data()?['coupleId'] as String? ?? '';
      }
      if (coupleId.isEmpty) return;
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
    // Tap notif (background/terminated) -> buka layar sesuai jenis.
    final type = msg.data['type'];
    if (type == 'call') {
      final callType = msg.data['callType'] ?? 'video';
      if (IncomingCallScreen.isShowing) return;
      navKey?.currentState?.pushNamed('/incomingCall', arguments: callType);
    } else if (type == 'chat') {
      navKey?.currentState?.pushNamed('/chat');
    }
  }

  /// Fallback Realtime -> Local Notification (tanpa server).
  void listenChatForLocalNotif(String coupleId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _db.collection('chats').doc(coupleId).collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .listen((snap) async {
        if (snap.docs.isEmpty) return;
        final doc = snap.docs.first;
        final data = doc.data();
        final fromId = data['fromId'];
        if (fromId == myUid) return;
        final ts = data['createdAt'] as Timestamp?;
        if (ts != null && DateTime.now().difference(ts.toDate()).inSeconds > 15) return;
        // Dedupe: kalau push FCM-nya SUDAH ditangani < 3 dtk lalu, jangan
        // dobel (dua jalur: server push + listener realtime).
        final last = _lastChatFcmAt;
        if (last != null && DateTime.now().difference(last).inSeconds < 3) return;
        try {
          final me = await _db.doc('users/$myUid').get();
          final prefs = me.data()?['notifPrefs'] as Map<String, dynamic>?;
          if (prefs != null && prefs['chat'] == false) return;
        } catch (_) {}
        final text = data['text'] ?? (data['imageUrl'] != null ? 'Foto' : 'Pesan baru');
        final title = (data['fromName'] as String?)?.isNotEmpty == true
            ? data['fromName'] as String
            : 'Pasangan';
        if (!_localReady) return;
        unawaited(RingtonePlayer.playNotif());
        await showRichChatNotif(
          _local,
          title: title,
          body: text,
          coupleId: coupleId,
          channelId: 'dykal_chat_realtime',
          channelName: 'DyKal Realtime',
        );
      });
  }

  /// Notifikasi "ada versi baru" (lokal & push topic app_updates).
  Future<void> showUpdateNotif(String title, {String body = 'Ada pembaruan baru. Sentuh untuk mengunduh.'}) async {
    if (!_localReady) return;
    final androidDetails = AndroidNotificationDetails(
      'dykal_update',
      'Info Update DyKal',
      channelDescription: 'Versi & pembaruan aplikasi terbaru',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFF6B8A),
      actions: [
        AndroidNotificationAction('download_update', 'Unduh Sekarang', showsUserInterface: true, cancelNotification: true),
      ],
    );
    await _local.show(
      880001,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'update',
    );
  }

  /// Progress unduhan sebagai notifikasi Android (id tetap 880002).
  Future<void> showDownloadProgress(int pct) async {
    if (!_localReady) return;
    final androidDetails = AndroidNotificationDetails(
      'dykal_update',
      'Info Update DyKal',
      channelDescription: 'Versi & pembaruan aplikasi terbaru',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: pct.clamp(0, 100),
      onlyAlertOnce: true,
      ongoing: true,
      color: const Color(0xFFFF6B8A),
    );
    await _local.show(
      880002,
      'Mengunduh update DyKal',
      '$pct%',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelDownloadNotif() async {
    if (!_localReady) return;
    try { await _local.cancel(880002); } catch (_) {}
  }

  /// Pesan data-only saat APP KILLED — berjalan di isolate latar.
  /// Di sini notif kaya dirender (sebelumnya handler ini cuma print!).
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (_) {
      return;
    }
    final data = message.data;
    final type = data['type'] ?? 'chat';
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      await plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification')));
    } catch (_) {}

    // Sinyal pembatalan panggilan -> hapus notif dering.
    if (type == 'call_cancel') {
      try { await plugin.cancel(notifIdCall); } catch (_) {}
      return;
    }
    // Update tetap hybrid (worker tak mengirim dataOnly utk topic).
    if (type == 'update') return;
    if (type == 'call') {
      await showRichCallNotif(plugin, data);
      return;
    }
    final title = (data['senderName'] as String?)?.isNotEmpty == true
        ? data['senderName'] as String
        : 'DyKal';
    final body = (data['messageBody'] as String?)?.isNotEmpty == true
        ? data['messageBody'] as String
        : 'Pesan baru';
    final cid = (data['coupleId'] as String?) ?? '';
    await showRichChatNotif(
      plugin,
      title: title,
      body: body,
      avatarUrl: data['senderAvatar'] as String?,
      coupleId: cid,
    );
    // BATCH I: pesan TIBA di device walau app mati -> centang 2 (delivered)
    // langsung, tak perlu menunggu app dibuka.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await markDeliveredFirestore(FirebaseFirestore.instance, cid, uid);
  }
}
