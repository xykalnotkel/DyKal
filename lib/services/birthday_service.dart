import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service Ucapan Ulang Tahun Otomatis
/// Karena Firebase Spark (No CC) tidak bisa pakai Cloud Functions Scheduled,
/// kita pakai LOCAL SCHEDULING via flutter_local_notifications (100% gratis, offline pun jalan)
class BirthdayService {
  final _firestore = FirebaseFirestore.instance;
  final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Makassar')); // Selong, NTB

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(InitializationSettings(android: android, iOS: ios));

    // Request permission Android 13+
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Simpan tanggal ultah kalian berdua di Firestore
  /// Collection: couples/dykal_couple_01
  /// Fields: birthdayA (Timestamp), birthdayB (Timestamp), nameA, nameB
  Future<void> saveBirthdays({required DateTime birthdayA, required DateTime birthdayB}) async {
    await _firestore.doc('couples/dykal_couple_01').set({
      'birthdayA': Timestamp.fromDate(birthdayA),
      'birthdayB': Timestamp.fromDate(birthdayB),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Jadwalkan notifikasi lokal untuk 2 tanggal tersebut tiap tahun
    await scheduleBirthday('Ayang', birthdayA);
    await scheduleBirthday('Aku', birthdayB);
  }

  /// Jadwalkan notifikasi jam 00:00 tepat di hari H
  Future<void> scheduleBirthday(String who, DateTime birthday) async {
    final now = DateTime.now();
    DateTime nextBirthday = DateTime(now.year, birthday.month, birthday.day, 0, 0);
    if (nextBirthday.isBefore(now)) {
      nextBirthday = DateTime(now.year + 1, birthday.month, birthday.day, 0, 0);
    }

    final androidDetails = AndroidNotificationDetails(
      'dykal_birthday',
      'DyKal Birthday',
      channelDescription: 'Ucapan ulang tahun otomatis',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      color: Color(0xFFFF6B8A),
    );

    await _notifications.zonedSchedule(
      who.hashCode,
      'Selamat Ulang Tahun ${who == "Ayang" ? "Sayang" : "Aku"}',
      who == "Ayang"
          ? 'Hari ini ulang tahun Ayang! Jangan lupa kasih kejutan dan surat cinta'
          : 'Hari ini ulang tahunmu! Semoga harimu indah, sayang sudah siapkan sesuatu',
      tz.TZDateTime.from(nextBirthday, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime, // Ulang tiap tahun
    );

    // Juga simpan ke Firestore biar di Home muncul banner otomatis
    await _firestore.collection('couples/dykal_couple_01/scheduled_greetings').doc(who).set({
      'who': who,
      'month': birthday.month,
      'day': birthday.day,
      'nextTrigger': Timestamp.fromDate(nextBirthday),
    });
  }

  /// Cek apakah hari ini ada yang ultah (dipanggil di HomeScreen init)
  Future<Map<String, dynamic>?> checkTodayIsBirthday() async {
    final doc = await _firestore.doc('couples/dykal_couple_01').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final now = DateTime.now();
    
    DateTime? bA = (data['birthdayA'] as Timestamp?)?.toDate();
    DateTime? bB = (data['birthdayB'] as Timestamp?)?.toDate();
    
    if (bA != null && bA.month == now.month && bA.day == now.day) {
      return {'who': data['nameA'] ?? 'Ayang', 'isA': true};
    }
    if (bB != null && bB.month == now.month && bB.day == now.day) {
      return {'who': data['nameB'] ?? 'Aku', 'isA': false};
    }
    return null;
  }

}
