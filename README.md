# DyKal 💕 — Aplikasi Couple Private

**DyKal** = **Dy** + **Kal** — Aplikasi private untuk kamu & dia. Chat, Call, Album, Surat & Home.

Desain modern seamless, tanpa garis pemisah, support 60/90/120Hz, DPI/No DPI.

---

## ✨ Fitur Lengkap

### 💬 Chat Super Lengkap
- Realtime Firestore
- Kirim Foto 1x Lihat (View Once) → via Cloudinary folder `view_once`, auto hapus setelah dibuka
- Edit Pesan & Hapus Pesan (isDeleted)
- Love Pesan (❤️) — favorit versi love
- Balas Pesan Swipe (swipe_to)
- Centang 1 (sent), Centang 2 (delivered), Centang 2 Biru (read)
- Sedang mengetik... / Sedang merekam audio... / Online/Offline (via presence collection)
- Voice Note dengan waveform

### 📞 Call Audio & Video
- **Audio Call**: Atur Volume (slider 0-1), mute, speaker, switch ke VideoCall tanpa putus
- **Video Call**: Filter/Efek (Normal, Warm, Cool, B&W, Beauty) via ColorFiltered, Bagi Layar (Screen Share) via `getDisplayMedia`, switch kamera, on/off kamera
- **TURN/STUN Gratis No CC**: `openrelay.metered.ca` (user: openrelayproject)

### 🎂 Ucapan Ulang Tahun Otomatis
- Simpan tanggal lahir 2 orang di `couples/dykal_couple_01` (birthdayA, birthdayB)
- **Otomatis jam 00:00** di hari H kirim notifikasi lokal ke masing-masing, tanpa Cloud Functions (pakai `flutter_local_notifications` + `zonedSchedule`)
- Banner di Home muncul otomatis jika hari ini ada yang ultah
- Timezone: `Asia/Makassar` (Selong)

### 📸 Album Foto
- Upload multi foto → **Cloudinary** (bukan Firebase Storage, jadi NO CC)
- Auto compress & convert ke **WebP** via `flutter_image_compress` (size 30-50% lebih kecil, tetap jernih di xxhdpi)
- Grid staggered masonry
- Cloudinary free: 25GB storage + 25GB bandwidth

### 💌 Surat Cinta
- Tulis surat dengan animasi amplop
- Koleksi `letters`
- Bisa di-love

### 🏠 Home
- Hero, stats, timeline kenangan, birthday banner

---

## 🎨 Design System DyKal — Modern Seamless

- **Warna**: Primary #FF6B8A (pink), Secondary #7B6CF6 (lavender), Bg #FFF8F9 (warm white)
- **TopBar & BottomNav**: Background SAMA dengan scaffold (`Colors.transparent` + `extendBody: true`), `elevation: 0`, `scrolledUnderElevation: 0` → **tanpa garis pemisah, nyatu**
- **Icons**: `phosphor_flutter` — variasi Regular / Fill / Bold / Light / Duotone (border/fill/full)
- **Font**: Poppins (title), Plus Jakarta Sans (body) via google_fonts
- **Ilustrasi**: 6 ilustrasi 3D flat vector AI generated, sudah di-remove bg & convert WebP (di `assets/illustrations/`)
- **Support DPI**: Semua asset pakai `cached_network_image` + `flutter_image_compress` minWidth 1080 (cukup untuk xxxhdpi & No DPI). Flutter auto scale via MediaQuery. Tidak pakai bitmap fixed DPI.
- **Support Refresh Rate**: `flutter_displaymode` → auto set ke mode tertinggi (60/90/120Hz) di `main.dart`

---

## 🔧 Setup Cepat 10 Menit (Tanpa Credit Card)

### 1. Firebase (Hanya Auth + Firestore + FCM)
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

# Di folder dykal_app
flutterfire configure --project=dykal-xxx
```
- Di console.firebase.google.com > Buat Project (Spark Free, JANGAN upgrade Blaze)
- Aktifin: Authentication (Email/Google), Firestore, Cloud Messaging
- **JANGAN aktifkan Storage** (yang minta CC). Kita pakai Cloudinary.

### 2. Cloudinary (Ganti Storage, NO CC)
1. Daftar di cloudinary.com (email doang)
2. Dashboard > Settings > Upload > **Upload presets** > Add preset > **Unsigned** > Nama: `dykal_unsigned` > Folder: `dykal` > Save
3. Copy **Cloud Name** (contoh: `dxxx123`)
4. Ganti di `lib/config/app_constants.dart`:
```dart
static const cloudinaryCloudName = "dxxx123";
static const cloudinaryUploadPreset = "dykal_unsigned";
```

### 3. Jalankan
```bash
flutter pub get
flutter run
```

---

## 📂 Struktur Project
```
lib/
  config/theme.dart, app_constants.dart
  services/cloudinary_service.dart, call_service.dart, birthday_service.dart
  models/chat_message.dart
  widgets/seamless_scaffold.dart, dykal_bottom_nav.dart
  screens/home, chat, call, album, letter
assets/illustrations/*.png (sudah WebP ready)
```

## 🔐 Firestore Rules (Hanya 2 orang)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
      // Untuk private strict: cek uid == "uid_aku" || uid == "uid_dia"
    }
  }
}
```

## 📱 Build APK
```bash
flutter build apk --release --split-per-abi
# Hasil: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (paling kecil)
```

---

## 🚀 Next Improvement (Opsional)
- E2E Encryption untuk chat (pakai `encrypt` package)
- Beauty filter real pakai Banuba / DeepAR (butuh SDK)
- Backup chat ke Cloudinary JSON

Dibuat dengan 💕 untuk DyKal. Selong, NTB — 2026.
