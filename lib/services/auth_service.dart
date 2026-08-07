import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Auth Service DyKal — Private Invite Code (Hanya Berdua)
/// Flow tanpa SMS/OTP mahal, gratis 100%:
/// 1. User daftar pakai Email + Password (atau Anonymous lalu link email)
/// 2. Jika belum punya couple → buat inviteCode (misal DYKAL-8X7A) di inviteCodes/{code}
/// 3. Pasangan login lalu input code → di-add ke couples/{coupleId}.members jadi 2 orang
/// 4. Setelah paired, semua rules Firestore otomatis kekunci hanya untuk 2 uid itu
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Daftar — cukup email & password (tanpa CC, tanpa OTP)
  Future<UserCredential> register({required String email, required String password, required String displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user!.updateDisplayName(displayName);
    // Buat profil user
    await _db.doc('users/${cred.user!.uid}').set({
      'uid': cred.user!.uid,
      'displayName': displayName,
      'email': email,
      'coupleId': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _saveFcmToken(cred.user!.uid);
    return cred;
  }

  Future<UserCredential> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken(cred.user!.uid);
    return cred;
  }

  // Buat Couple + Invite Code (yang pertama buat)
  Future<String> createCoupleAndInviteCode() async {
    final uid = _auth.currentUser!.uid;
    final coupleId = 'couple_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final code = _generateCode(); // DYKAL-8X7A

    // 1. Buat couples/{coupleId} dengan 1 member dulu
    await _db.doc('couples/$coupleId').set({
      'coupleId': coupleId,
      'members': [uid],
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'anniversary': null,
    });

    // 2. Buat inviteCodes/{code} -> coupleId
    await _db.doc('inviteCodes/$code').set({
      'code': code,
      'coupleId': coupleId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
    });

    // 3. Update user.coupleId
    await _db.doc('users/$uid').set({'coupleId': coupleId}, SetOptions(merge: true));

    return code;
  }

  // Join pakai kode (pasangan yang kedua)
  Future<String> joinWithCode(String code) async {
    code = code.trim().toUpperCase();
    final uid = _auth.currentUser!.uid;

    final inviteSnap = await _db.doc('inviteCodes/$code').get();
    if (!inviteSnap.exists) throw Exception('Kode tidak ditemukan');
    final data = inviteSnap.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) throw Exception('Kode sudah expired');

    final coupleId = data['coupleId'] as String;
    final coupleRef = _db.doc('couples/$coupleId');
    final coupleSnap = await coupleRef.get();
    final members = List<String>.from(coupleSnap.data()!['members']);

    if (members.contains(uid)) throw Exception('Kamu sudah bergabung di couple ini');
    if (members.length >= 2) throw Exception('Couple sudah penuh (maks 2 orang)');

    // Tambah member ke-2
    await coupleRef.update({
      'members': FieldValue.arrayUnion([uid]),
      'pairedAt': FieldValue.serverTimestamp(),
    });

    // Update user.coupleId
    await _db.doc('users/$uid').set({'coupleId': coupleId}, SetOptions(merge: true));

    // Hapus invite code setelah dipakai (sekali pakai)
    await _db.doc('inviteCodes/$code').delete();

    await _saveFcmToken(uid);
    return coupleId;
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Set offline
      await _db.doc('presence/$uid').set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await _auth.signOut();
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.doc('users/$uid').set({'fcmToken': token, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // tanpa O/0/I/1 biar tidak bingung
    final rnd = DateTime.now().millisecondsSinceEpoch;
    String s = '';
    for (int i = 0; i < 4; i++) s += chars[(rnd + i * 37) % chars.length];
    return 'DYKAL-$s';
  }
}
