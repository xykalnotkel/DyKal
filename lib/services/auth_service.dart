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
  String? _myAvatarShape; // shape avatar (custom seperti album)
  String? partnerPhotoUrl;
  bool _userDocChecked = false; // ensureUserDoc auto-call: sekali per sesi
  String get myId => _auth.currentUser?.uid ?? '';
  String get myName => _myName ?? _auth.currentUser?.displayName ?? '';
  String get myStatus => _myStatus ?? '';
  String get myAvatarShape => _myAvatarShape ?? 'bulat';

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Stream coupleId user ini (dipakai AuthGate untuk routing otomatis)
  Stream<String?> coupleIdStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db.doc('users/$uid').snapshots().map((s) => s.data()?['coupleId'] as String?);
  }

  Future<UserCredential> register({required String email, required String password, required String displayName, String? photoUrl}) async {
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // SAFETY NET (bug pendaftaran era dulu): akun bisa terlanjur terbuat di
      // server walau respons gagal didekode plugin -> user kelihatan "gagal
      // daftar" padahal akun ada TANPA doc users. Pulihkan doc dulu, baru
      // lempar errornya ke UI.
      if (_auth.currentUser != null) {
        await ensureUserDoc(displayName: displayName, photoUrl: photoUrl);
      }
      rethrow;
    }
    final uid = cred.user!.uid;
    // FIX REGISTRASI: tulis users doc DULU (paling penting - nama wajib kesimpen).
    // Non-fatal: kalau gagal (jaringan/rules), doc disembuhkan otomatis oleh
    // ensureUserDoc() pada login/app-start berikutnya — displayName TIDAK akan
    // hilang permanen sampai harus edit profil manual seperti dulu.
    try {
      await _db.doc('users/$uid').set({
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'coupleId': null,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    _myName = displayName;   // cache langsung
    myPhotoUrl = photoUrl;
    // updateDisplayName Auth non-kritis (jangan block registrasi kalau gagal)
    try { await cred.user!.updateDisplayName(displayName); } catch (_) {}
    await _saveFcmToken(uid);
    _userDocChecked = true;
    return cred;
  }

  Future<UserCredential> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await ensureUserDoc(); // self-heal akun lama: doc hilang / displayName kosong
    await _saveFcmToken(cred.user!.uid);
    return cred;
  }

  /// Pastikan doc users/{uid} ada & displayName terisi.
  /// Menyembuhkan akun era bug: akun Auth terbuat tapi doc Firestore tidak
  /// sempat ditulis -> nama kosong sampai user edit profil manual.
  /// Dipanggil saat register, login, dan setiap app start (AuthGate).
  /// Urutan fallback nama: parameter -> displayName Auth -> prefix email.
  Future<void> ensureUserDoc({String? displayName, String? photoUrl}) async {
    if (_userDocChecked && displayName == null) return; // sekali per sesi utk auto-call
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.doc('users/${user.uid}');
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        final name = _fallbackName(displayName, user);
        await ref.set({
          'uid': user.uid,
          'displayName': name,
          'email': user.email,
          'photoUrl': photoUrl,
          'coupleId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _myName = name;
      } else {
        final data = snap.data()!;
        final patch = <String, dynamic>{};
        final dn = (data['displayName'] as String?) ?? '';
        if (dn.trim().isEmpty) patch['displayName'] = _fallbackName(displayName, user);
        if (!data.containsKey('coupleId')) patch['coupleId'] = null;
        if (!data.containsKey('email') && user.email != null) patch['email'] = user.email;
        if (patch.isNotEmpty) {
          await ref.set(patch, SetOptions(merge: true));
          final fixed = patch['displayName'] as String?;
          if (fixed != null) _myName = fixed;
        }
      }
      _userDocChecked = true;
    } catch (_) {}
  }

  String _fallbackName(String? displayName, User user) {
    for (final c in [displayName, user.displayName, user.email?.split('@').first]) {
      if (c != null && c.trim().isNotEmpty) return c.trim();
    }
    return 'User';
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
      _myAvatarShape = meSnap.data()?['avatarShape'] as String?;
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
        // Self-heal nama kosong di doc couple (era bug: couple terbuat dengan
        // displayNameA/B '' karena doc users belum ada saat createCouple).
        final nm = _myName ?? '';
        if (nm.isNotEmpty && members.contains(uid)) {
          final cData = cSnap.data()!;
          final iAmA = members.first == uid;
          final patchC = <String, dynamic>{};
          if (iAmA && (((cData['displayNameA'] as String?) ?? '').trim().isEmpty)) {
            patchC['displayNameA'] = nm;
            if (myPhotoUrl != null && cData['photoA'] == null) patchC['photoA'] = myPhotoUrl;
          }
          if (!iAmA && (((cData['displayNameB'] as String?) ?? '').trim().isEmpty)) {
            patchC['displayNameB'] = nm;
            if (myPhotoUrl != null && cData['photoB'] == null) patchC['photoB'] = myPhotoUrl;
          }
          if (patchC.isNotEmpty) {
            try { await _db.doc('couples/$coupleId').set(patchC, SetOptions(merge: true)); } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// Bersihkan coupleId usang (doc couple tidak ada / setengah jadi).
  /// Dipakai AuthGate saat mendeteksi referensi couple yatim.
  Future<void> clearStaleCouple() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try { await _db.doc('users/$uid').set({'coupleId': null}, SetOptions(merge: true)); } catch (_) {}
    }
    coupleId = partnerId = partnerName = partnerPhotoUrl = null;
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.doc('presence/$uid').set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    coupleId = partnerId = partnerName = myPhotoUrl = partnerPhotoUrl = null;
    _userDocChecked = false; // biar login berikutnya ensureUserDoc jalan lagi
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
