import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Auth Service DyKal — Email + Password + Invite Code (Hanya Berdua)
/// Flow:
/// 1. Daftar Email + Password
/// 2. Belum punya couple -> buat inviteCode (DYKAL-XXXX, 24 jam)
/// 3. Pasangan daftar & input code -> couples/{coupleId}.members jadi 2 orang
/// 4. Setelah paired, data dikunci hanya untuk 2 uid (lihat firestore.rules)
class AuthService {
  static final AuthService _i = AuthService._();
  AuthService._();
  factory AuthService() => _i;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Cache pasangan (diisi setelah login/pairing)
  String? coupleId;
  String? partnerId;
  String? partnerName;
  String? myPhotoUrl;
  String? _myName; // FIX: cache nama dari Firestore (Auth displayName sering kosong)
  String? _myStatus; // status/bio singkat dari Firestore
  String? partnerPhotoUrl;
  String get myId => _auth.currentUser?.uid ?? '';
  String get myName => _myName ?? _auth.currentUser?.displayName ?? '';
  String get myStatus => _myStatus ?? '';

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Stream coupleId user ini (dipakai AuthGate untuk routing otomatis)
  Stream<String?> coupleIdStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db.doc('users/$uid').snapshots().map((s) => s.data()?['coupleId'] as String?);
  }

  Future<UserCredential> register({required String email, required String password, required String displayName, String? photoUrl}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    // FIX REGISTRASI: tulis users doc DULU (paling penting - nama wajib kesimpen)
    await _db.doc('users/$uid').set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'coupleId': null,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _myName = displayName;   // cache langsung
    myPhotoUrl = photoUrl;
    // updateDisplayName Auth non-kritis (jangan block registrasi kalau gagal)
    try { await cred.user!.updateDisplayName(displayName); } catch (_) {}
    await _saveFcmToken(uid);
    return cred;
  }

  Future<UserCredential> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken(cred.user!.uid);
    return cred;
  }

  /// Buat couple + invite code (yang pertama)
  Future<String> createCoupleAndInviteCode() async {
    final uid = _auth.currentUser!.uid;
    final coupleId = 'couple_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final code = _generateCode();
    final meSnap = await _db.doc('users/$uid').get();
    final myNm = meSnap.data()?['displayName'] as String? ?? '';

    await _db.doc('couples/$coupleId').set({
      'coupleId': coupleId,
      'members': [uid],
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'anniversary': null,
      'birthdayA': null,
      'birthdayB': null,
      'inviteCode': code,
      'displayNameA': myNm,
      'displayNameB': null,
      'photoA': myPhotoUrl,
      'photoB': null,
    });

    await _db.doc('inviteCodes/$code').set({
      'code': code,
      'coupleId': coupleId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
    });

    await _db.doc('users/$uid').set({'coupleId': coupleId}, SetOptions(merge: true));
    await refresh();
    return code;
  }

  /// Join pakai kode (pasangan kedua)
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
    if (!coupleSnap.exists) throw Exception('Couple tidak ditemukan');
    final members = List<String>.from(coupleSnap.data()!['members'] ?? []);
    final meSnapJ = await _db.doc('users/$uid').get();
    final myNmJ = meSnapJ.data()?['displayName'] as String? ?? '';

    if (members.contains(uid)) throw Exception('Kamu sudah bergabung di couple ini');
    if (members.length >= 2) throw Exception('Couple sudah penuh (maks 2 orang)');

    await coupleRef.update({
      'members': FieldValue.arrayUnion([uid]),
      'pairedAt': FieldValue.serverTimestamp(),
      'displayNameB': myNmJ,
      'photoB': myPhotoUrl,
    });

    await _db.doc('users/$uid').set({'coupleId': coupleId}, SetOptions(merge: true));
    await _db.doc('inviteCodes/$code').delete();
    await _saveFcmToken(uid);
    await refresh();
    return coupleId;
  }

  /// Isi cache coupleId/partnerId/partnerName dari Firestore
  Future<void> refresh() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      coupleId = partnerId = partnerName = myPhotoUrl = partnerPhotoUrl = null;
      return;
    }
    try {
      final meSnap = await _db.doc('users/$uid').get();
      coupleId = meSnap.data()?['coupleId'] as String?;
      myPhotoUrl = meSnap.data()?['photoUrl'] as String?;
      _myName = meSnap.data()?['displayName'] as String?;
      _myStatus = meSnap.data()?['status'] as String?;
      if (coupleId != null) {
        final cSnap = await _db.doc('couples/$coupleId').get();
        final members = List<String>.from(cSnap.data()?['members'] ?? []);
        final others = members.where((m) => m != uid).toList();
        partnerId = others.isNotEmpty ? others.first : null;
        if (partnerId != null && partnerId!.isNotEmpty) {
          final pSnap = await _db.doc('users/$partnerId').get();
          partnerName = pSnap.data()?['displayName'] ?? '';
          partnerPhotoUrl = pSnap.data()?['photoUrl'] as String?;
        }
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.doc('presence/$uid').set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    coupleId = partnerId = partnerName = myPhotoUrl = partnerPhotoUrl = null;
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final s = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'DYKAL-$s';
  }
}
