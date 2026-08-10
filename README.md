# DYKAL - PRIVATE COUPLE ECOSYSTEM

Aplikasi private khusus dua pengguna yang mengintegrasikan Realtime Messaging, VoIP Calls (WebRTC), Enkripsi Media Lokal Scoped Storage, Shared Album, dan Surat Digital.

---

## 1. ARSITEKTUR SISTEM & TEKNOLOGI

- Framework: Flutter 3.44+ / Dart 3.12+ (Null Safety, Modern Material 3 Tokens)
- State & Architecture: Service Singleton + ListenableBuilder + Local-First Sync Architecture
- Realtime Backend: Google Cloud Firestore (Security Rules Hardened)
- Media Storage: Cloudinary Unsigned Engine + WhatsApp-style Scoped Media Storage (`Android/media/com.dykal.app/Dykal/Media/`)
- Panggilan Audio & Video: WebRTC Native Peer Connection + STUN/TURN Signalling
- Push Notification: Cloudflare Worker (FCM HTTP v1 Protocol) + Android Local Notifications System
- Enkripsi Stiker & Media Private: AES-256-GCM Hardware Cipher (`.webp.crypt15`)

---

## 2. STRUKTUR MEDIA LOKAL (WHATSAPP STANDARDS)

Semua media disimpan rapi di direktori scoped storage Android:
`Android/media/com.dykal.app/Dykal/Media/`

Sub-folder yang terstruktur:
1. `Dykal Images/` : Foto masuk dari pasangan (terindeks di Galeri).
2. `Dykal Images/Sent/` : Foto yang dikirim pengguna (disembunyikan dari Galeri via file `.nomedia`).
3. `Dykal Images/Private/` : Foto sekali lihat / View-Once (disembunyikan via file `.nomedia`).
4. `Dykal Video/` : Video masuk & video keluar (`Sent/` + `.nomedia`).
5. `Dykal Audio/` : File audio masuk & rekaman suara pasangan (`Dykal Voice Notes/` + `.nomedia`).
6. `Dykal Documents/` : Dokumen surat dan cadangan data.
7. `Dykal Stickers/` : Stiker kustom terenkripsi (`.webp.crypt15` + `.nomedia`).

---

## 3. DESIGN SYSTEM & TEMA

- Mode Terang (Light Mode):
  - Primary: `#FF6B8A` (Soft Rose Pastel)
  - Background: `#FFF8F9` (Warm White)
  - Surface: `#FFFFFF`
- Mode Gelap (TikTok Soft Dark):
  - Primary Accent: `#FE2C55` / `#FF6B8A`
  - Background: `#121212` (Matte Neutral Dark)
  - Elevated Card: `#1F2029` (Soft Dark Slate)
  - Subtle Border: Transparan 8% (`withValues(alpha: 0.08)`)
  - Text Primary: `#FFFFFF`
  - Text Muted: `#8A8B91` (TikTok Clean Gray)
- Komponen Khusus:
  - `DyKalSkeleton` : Shimmer loader adaptif Dark/Light
  - `DyKalImage` : Smart image caching dengan fallback error handler
  - `DyKalButton` : State button dengan indikator loading otomatis

---

## 4. KEBIJAKAN IZIN ANDROID (GOOGLE PLAY COMPLIANT)

Aplikasi ini menggunakan komunikasi VoIP (Voice over IP) berbasis data internet dan mematuhi kebijakan Google Play Console:
- Menggunakan: `RECORD_AUDIO`, `CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `USE_FULL_SCREEN_INTENT`, `MANAGE_OWN_CALLS`.
- Menghapus: Seluruh izin GSM seluler terlarang (`READ_CALL_LOG`, `WRITE_CALL_LOG`, `CALL_PHONE`, `READ_PHONE_STATE`, `ANSWER_PHONE_CALLS`) untuk mencegah penolakan (rejection) pada proses rilis Play Store.

---

## 5. BUILD & RELEASE

Untuk menghasilkan file release Android:

1. Buat APK Universal:
   ```bash
   flutter build apk --release
   ```

2. Buat App Bundle (AAB) untuk Google Play Console:
   ```bash
   flutter build appbundle --release
   ```
