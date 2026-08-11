import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'auth_service.dart';

/// Service notifikasi terjadwal (Ultah & Anniversary) — 100% gratis via local notif.
class BirthdayService {
  final _firestore = FirebaseFirestore.instance;
  final _notifications = FlutterLocalNotificationsPlugin();

  String get _coupleId => AuthService().coupleId ?? '';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(const InitializationSettings(android: android, iOS: ios));

    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  /// Jadwalkan notif ulang tahun untuk A & B (dipanggil dari Profil)
  Future<void> scheduleBirthdays({required DateTime birthdayA, required DateTime birthdayB, required String nameA, required String nameB}) async {
    await _scheduleBirthday(nameA, birthdayA, 88001);
    await _scheduleBirthday(nameB, birthdayB, 88002);
  }

  /// Jadwalkan notif anniversary (tiap tahun)
  Future<void> scheduleAnniversary(DateTime anniversary) async {
    final now = DateTime.now();
    DateTime next = DateTime(now.year, anniversary.month, anniversary.day, 9, 0);
    if (next.isBefore(now)) next = DateTime(now.year + 1, anniversary.month, anniversary.day, 9, 0);

    final androidDetails = AndroidNotificationDetails(
      'dykal_birthday', 'DyKal Moment',
      channelDescription: 'Ultah & anniversary',
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: true,
      styleInformation: BigTextStyleInformation('Selamat anniversary kalian!'),
      color: const Color(0xFFFF6B8A),
    );
    await _notifications.zonedSchedule(
      99001,
      'Anniversary DyKal',
      'Selamat anniversary! Sekian tahun bersama',
      tz.TZDateTime.from(next, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _scheduleBirthday(String name, DateTime birthday, int id) async {
    final now = DateTime.now();
    DateTime next = DateTime(now.year, birthday.month, birthday.day, 0, 1);
    if (next.isBefore(now)) next = DateTime(now.year + 1, birthday.month, birthday.day, 0, 1);

    final androidDetails = AndroidNotificationDetails(
      'dykal_birthday', 'DyKal Moment',
      channelDescription: 'Ultah & anniversary',
      importance: Importance.max,
      priority: Priority.high,
      channelShowBadge: true,
      styleInformation: BigTextStyleInformation('Jangan lupa ucapan & kejutan'),
      color: const Color(0xFFFF6B8A),
    );
    await _notifications.zonedSchedule(
      id,
      'Selamat Ulang Tahun $name',
      'Hari ini ulang tahun $name! Kasih kejutan & surat cinta yuk',
      tz.TZDateTime.from(next, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Cek apakah hari ini ada yang ultah (banner Home)
  Future<Map<String, dynamic>?> checkTodayIsBirthday() async {
    if (_coupleId.isEmpty) return null;
    final doc = await _firestore.doc('couples/$_coupleId').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final now = DateTime.now();
    final bA = (data['birthdayA'] as Timestamp?)?.toDate();
    final bB = (data['birthdayB'] as Timestamp?)?.toDate();
    if (bA != null && bA.month == now.month && bA.day == now.day) {
      return {'who': data['displayNameA'] ?? '', 'isA': true};
    }
    if (bB != null && bB.month == now.month && bB.day == now.day) {
      return {'who': data['displayNameB'] ?? '', 'isA': false};
    }
    return null;
  }
}
