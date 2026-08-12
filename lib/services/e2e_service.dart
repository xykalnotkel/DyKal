import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';

/// Service E2EE media DyKal — pertanyaan owner: "bisa ga media yg diupload ke
/// Cloudinary/Firebase dienkripsi, sampe AKU sendiri ga bisa liat?"
/// JAWABAN + KENAPA desainnya begini:
///
/// 1. Kunci TIDAK BOLEH dipegang owner. Kalau owner pegang kunci, klaim
///    "owner pun ga bisa lihat" jadi bohong — owner tinggal unduh ciphertext
///    + dekripsi. Jadi kunci hanya lahir & hidup di 2 HP pasangan.
/// 2. Tukar kunci pakai ECDH X25519: tiap HP punya keypair, yang diumumkan
///    ke Firestore HANYA public key (`users/{uid}.e2ePubKey`). Public key
///    tidak bisa dipakai membuka apa pun. Kunci bersama diturunkan lokal:
///    X25519(privA, pubB) == X25519(privB, pubA) — backend cuma lihat
///    public key, tidak pernah melihat kunci bersama.
/// 3. Private key disimpan flutter_secure_storage (Android Keystore-backed,
///    terenkripsi hardware bila tersedia).
/// 4. File media: [12B nonce][ciphertext+tag AES-256-GCM], diupload sebagai
///    resource RAW ke folder `dykal/e2e`. Penanda E2E = segmen URL
///    '/dykal/e2e/' — nol perubahan skema Firestore, media lama (plaintext)
///    tetap tampil normal.
/// 5. Fallback: kalau pasangan belum punya public key (app versi lama),
///    upload jalan plaintext seperti biasa (kenaikan versi tidak memutus
///    chat). Begitu dua-duanya v1.2.0+, semua media baru otomatis E2E.
class E2EService {
  E2EService._();

  static const marker = '/dykal/e2e/';
  static const _kPriv = 'e2e_x25519_priv';
  static const _kPub = 'e2e_x25519_pub';
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Uint8List? _sharedCache; // cache kunci bersama untuk proses ini

  static bool isEncryptedUrl(String? url) => (url ?? '').contains(marker);

  /// Pastikan keypair device ada & public key terbit di users/{uid}.
  /// Idempoten — aman dipanggil berkali-kali.
  static Future<void> ensureKeyPair() async {
    final uid = AuthService().myId;
    if (uid.isEmpty) return;
    try {
      var priv = await _store.read(key: _kPriv);
      var pub = await _store.read(key: _kPub);
      if (priv == null || pub == null) {
        final kp = await X25519().newKeyPair();
        final data = await kp.extract(); // SimpleKeyPairData
        priv = base64Encode(Uint8List.fromList(data.privateKey));
        pub = base64Encode(Uint8List.fromList(data.publicKey.bytes));
        await _store.write(key: _kPriv, value: priv);
        await _store.write(key: _kPub, value: pub);
      }
      // Public key memang untuk dibagikan — tulis (merge) tiap sesi biar
      // pasangan pasti menemukannya.
      await FirebaseFirestore.instance.doc('users/$uid').set(
        {'e2ePubKey': pub},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Label status E2E untuk UI Pengaturan.
  static Future<String> statusLabel() async {
    try {
      final key = await _sharedKey();
      if (key != null) return 'Aktif — kunci bersama siap (X25519 + AES-256-GCM)';
      final partnerId = AuthService().partnerId ?? '';
      if (partnerId.isEmpty) return 'Menunggu pairing';
      return 'Menunggu pasangan update ke versi terbaru';
    } catch (_) {
      return 'Belum siap';
    }
  }

  /// Kunci AES-256 bersama couple; null jika pasangan belum mempublikasikan
  /// public key (app versi lama) -> caller fallback plaintext.
  static Future<Uint8List?> _sharedKey() async {
    if (_sharedCache != null) return _sharedCache;
    try {
      await ensureKeyPair();
      final partnerId = AuthService().partnerId ?? '';
      if (partnerId.isEmpty) return null;
      final privB64 = await _store.read(key: _kPriv);
      if (privB64 == null) return null;
      final pSnap = await FirebaseFirestore.instance.doc('users/$partnerId').get();
      final partnerPubB64 = pSnap.data()?['e2ePubKey'] as String?;
      if (partnerPubB64 == null || partnerPubB64.isEmpty) return null;

      final myPair = await X25519().newKeyPairFromSeed(base64Decode(privB64));
      final partnerPub = SimplePublicKey(
        base64Decode(partnerPubB64),
        type: KeyPairType.x25519,
      );
      final shared = await X25519().sharedSecretKey(
        keyPair: myPair,
        remotePublicKey: partnerPub,
      );
      final bytes = Uint8List.fromList(await shared.extractBytes());
      if (bytes.length != 32) return null;
      _sharedCache = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Enkripsi file -> File ciphertext (format: nonce+ciphertext+tag).
  /// null = E2E belum siap -> caller fallback upload plaintext biasa.
  static Future<File?> encryptFile(File src) async {
    try {
      final key = await _sharedKey();
      if (key == null) return null;
      final plain = await src.readAsBytes();
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      );
      final out = encrypter.encryptBytes(plain, iv: iv);
      final tmp = await getTemporaryDirectory();
      final f = File(
        '${tmp.path}/e2e_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.bin',
      );
      await f.writeAsBytes(Uint8List.fromList(iv.bytes + out.bytes));
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Dekripsi blob ciphertext (format nonce+cipher+tag). null jika bukan
  /// file kita / korup / kunci belum ada.
  static Future<Uint8List?> decryptBlob(Uint8List blob) async {
    try {
      final key = await _sharedKey();
      if (key == null || blob.length < 29) return null;
      final iv = enc.IV(Uint8List.fromList(blob.sublist(0, 12)));
      final ct = enc.Encrypted(Uint8List.fromList(blob.sublist(12)));
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      );
      final plain = encrypter.decryptBytes(ct, iv: iv);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  /// Unduh URL E2E -> dekripsi -> file lokal plaintext.
  /// File plaintext inilah yang jg membuat media E2E bisa dibuka OFFLINE
  /// (caller mencatatnya ke MediaCache/VoiceCache seperti biasa).
  static Future<String?> downloadDecrypted(String url, {String ext = 'webp'}) async {
    try {
      final res = await Dio()
          .get<List<int>>(url, options: Options(responseType: ResponseType.bytes))
          .timeout(const Duration(seconds: 60));
      final data = res.data;
      if (data == null || data.isEmpty) return null;
      final plain = await decryptBlob(Uint8List.fromList(data));
      if (plain == null) return null;
      final tmp = await getTemporaryDirectory();
      final f = File(
        '${tmp.path}/e2e_plain_${url.hashCode.abs()}.$ext',
      );
      await f.writeAsBytes(plain);
      return f.path;
    } catch (_) {
      return null;
    }
  }
}
