# Firebase Setup DyKal — Auth, Firestore Rules, FCM (Free Spark No CC)

Dokumen ini khusus untuk pertanyaan lu: **firestore rules gimana? Auth? FCM?**

---

## 1. Auth — Private Invite Code (Hanya Berdua, Gratis)

Kita **tidak pakai OTP SMS** (mahal & butuh CC). Pakai **Email + Password + Invite Code**.

**Flow:**
- User A Daftar → `AuthService.register()` → otomatis buat `users/{uid}` → `createCoupleAndInviteCode()` → dapat kode `DYKAL-8X7A` → simpan di `inviteCodes/{code}` & `couples/{coupleId}.members = [uidA]`
- User B Daftar → input kode di PairingScreen → `joinWithCode("DYKAL-8X7A")` → `couples/{coupleId}.members` jadi `[uidA, uidB]` → code dihapus (sekali pakai) → keduanya sekarang bisa akses semua koleksi.

**Setup di Console:**
- Firebase Console → Authentication → Sign-in method → **Email/Password → Enable** (sudah cukup)
- Tidak perlu Phone, Google, dll.

**File:** `lib/services/auth_service.dart` sudah jadi. Di `main.dart` cek:
```dart
if (FirebaseAuth.instance.currentUser == null) Navigator.push(PairingScreen())
else if (user.coupleId == null) Navigator.push(PairingScreen()) // belum paired
else MainNav()
```

---

## 2. Firestore Rules — Kunci Hanya Berdua

File rules sudah ada di `firestore.rules`. Intinya:

- **members array** di `couples/{coupleId}` adalah sumber kebenaran. Semua koleksi cek `isMemberOfCouple(coupleId)` via `get(/databases/.../couples/{id}).data.members`.
- **InviteCodes**: `allow get` (baca 1 code) boleh login, tapi `allow list` false (tidak bisa ngintip semua code).
- **Chats/Messages**: `create` hanya jika `fromId == auth.uid` dan dia member couple itu. `update` hanya field `text,isEdited,isDeleted,isLoved,status,viewOnceOpened` (cegah ngubah fromId).
- **Presence**: user hanya bisa tulis `presence/{uid miliknya}` sendiri.
- **Users**: hanya bisa update `users/{uid miliknya}` dan hanya field `displayName,photoUrl,birthday,fcmToken,lastSeen,coupleId`.
- **Calls**: hanya caller/callee yang terlibat.

**Deploy Rules:**
```bash
# Install Firebase CLI
npm i -g firebase-tools
firebase login
firebase init firestore # pilih project dykal, pilih file firestore.rules
firebase deploy --only firestore:rules
# Atau copy-paste manual: Firebase Console → Firestore → Rules → paste isi firestore.rules → Publish
```

**Indexes (penting untuk chat):**
Buat di `firestore.indexes.json` lalu deploy:
```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```
Atau biarkan Firebase auto-prompt saat query pertama error → klik link buat index.

---

## 3. FCM — Push Notifikasi Gratis

**Yang sudah ada:** `lib/services/fcm_service.dart`

**Setup Android:**

1. `android/app/build.gradle` → sudah ada `apply plugin: 'com.google.gms.google-services'` setelah `flutterfire configure`.
2. `android/app/src/main/AndroidManifest.xml` → tambah di `<manifest>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
Di `<application>` sudah auto ada `meta-data` FCM.

3. `lib/main.dart`:
```dart
import 'lib/services/fcm_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService().init(); // request permission + simpan token
  FirebaseMessaging.onBackgroundMessage(FCMService.firebaseMessagingBackgroundHandler);
  runApp(...);
  // Setelah login & dapat coupleId:
  FCMService().listenChatForLocalNotif(coupleId); // fallback realtime
}
```

4. `lib/services/birthday_service.dart` + FCMService local channel sudah handle `POST_NOTIFICATIONS` Android 13+.

**Setup iOS (jika build iOS):**
- Xcode → Signing & Capabilities → + Push Notifications + Background Modes → Remote notifications
- Upload APNs key di Firebase Console → Project Settings → Cloud Messaging → APNs.

**Cara Kirim Notif (Free Spark tanpa Cloud Functions):**

- **Opsi A — Realtime Fallback (sudah jalan 100% gratis):** `listenChatForLocalNotif()` akan listen `chats/{coupleId}/messages` limit 1. Tiap pesan baru dari pasangan → trigger `flutter_local_notifications` langsung di device penerima (work saat app foreground/background tapi tidak killed). Untuk 2 orang ini sudah 95% cukup.

- **Opsi B — FCM Push saat app killed (butuh Blaze):** Jika mau 100% reliable saat app di-kill, butuh Cloud Functions. Workaround gratis: kirim FCM via HTTP dari device pengirim (tidak disarankan untuk production tapi bisa untuk private 2 orang). Contoh:
```dart
// Di _sendMessage() setelah set doc
final partnerDoc = await _db.doc('users/$partnerId').get();
final token = partnerDoc.data()?['fcmToken'];
if (token != null) {
  // Panggil FCM HTTP v1 via Cloud Function gratis alternatif (pakai http ke fcm.googleapis.com)
  // Simpan serverKey di secrets, jangan hardcode
}
```
Atau upgrade Blaze (tetap gratis 2M invocations) dan deploy Function 10 baris untuk `onCreate messages → send FCM`.

**Test FCM:**
- Firebase Console → Cloud Messaging → Send test message → paste FCM token dari log `FCM Token: ...`
- Atau kirim chat baru → cek notifikasi muncul.

**File Penting:**
- `firestore.rules` → deploy
- `lib/services/auth_service.dart` → pakai di PairingScreen
- `lib/services/fcm_service.dart` → init di main
- `android/app/google-services.json` → dari Firebase Console, jangan lupa tambah ke `.gitignore` dan encode ke base64 untuk GitHub Actions secret `GOOGLE_SERVICES_JSON_BASE64`

Sudah siap — tinggal `firebase deploy --only firestore:rules` dan `flutterfire configure`.
