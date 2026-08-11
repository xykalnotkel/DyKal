<p align="center">
  <img src="assets/logo/dykal_launcher.png" width="120" alt="DyKal Logo" />
</p>

<h1 align="center">DyKal</h1>

<p align="center"><b>Private Couple Ecosystem</b> — satu aplikasi, dua orang, nol distraksi.<br/>
Produk pertama dari <b>XYSTUDIO</b> oleh <b>Kall</b>.</p>

<!-- ===================== WALL OF BADGES ===================== -->
<p align="center">
  <a href="https://github.com/xykalnotkel/DyKal/releases"><img src="https://img.shields.io/github/v/release/xykalnotkel/DyKal?style=for-the-badge&label=RELEASE&color=FF6B8A" alt="Release"/></a>
  <a href="https://github.com/xykalnotkel/DyKal/releases"><img src="https://img.shields.io/github/downloads/xykalnotkel/DyKal/total?style=for-the-badge&color=FE2C55&label=DOWNLOADS" alt="Downloads"/></a>
  <img src="https://img.shields.io/github/last-commit/xykalnotkel/DyKal?style=for-the-badge&color=7B6CF6&label=LAST%20COMMIT" alt="Last Commit"/>
  <img src="https://img.shields.io/github/languages/code-size/xykalnotkel/DyKal?style=for-the-badge&color=FFC857&label=CODE%20SIZE" alt="Code Size"/>
</p>
<p align="center">
  <a href="https://github.com/xykalnotkel/DyKal/actions/workflows/build-apk.yml"><img src="https://github.com/xykalnotkel/DyKal/actions/workflows/build-apk.yml/badge.svg?branch=main" alt="Build APK"/></a>
  <a href="https://github.com/xykalnotkel/DyKal/actions/workflows/release.yml"><img src="https://github.com/xykalnotkel/DyKal/actions/workflows/release.yml/badge.svg?branch=main" alt="Release"/></a>
  <a href="https://github.com/xykalnotkel/DyKal/actions/workflows/deploy-firestore.yml"><img src="https://github.com/xykalnotkel/DyKal/actions/workflows/deploy-firestore.yml/badge.svg?branch=main" alt="Deploy Rules"/></a>
  <a href="https://github.com/xykalnotkel/DyKal/actions/workflows/deploy-worker.yml"><img src="https://github.com/xykalnotkel/DyKal/actions/workflows/deploy-worker.yml/badge.svg?branch=main" alt="Deploy Worker"/></a>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/FLUTTER-3.44.9-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/DART-%3E%3D3.6.0-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/ANDROID-MIN%20SDK%2024-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/FIREBASE-AUTH%20%C2%B7%20FIRESTORE%20%C2%B7%20FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/CLOUDFLARE-PUSH%20WORKER-F3801F?style=for-the-badge&logo=cloudflare&logoColor=white" alt="Cloudflare"/>
  <img src="https://img.shields.io/badge/CLOUDINARY-MEDIA%20CDN-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white" alt="Cloudinary"/>
  <img src="https://img.shields.io/badge/WEBRTC-P2P%20CALLS-333333?style=for-the-badge&logo=webrtc&logoColor=white" alt="WebRTC"/>
  <img src="https://img.shields.io/badge/ENKRIPSI-AES--256--GCM-4ECDC4?style=for-the-badge" alt="Encryption"/>
</p>

---

## Tentang

DyKal adalah ruang digital privat untuk dua orang: chat realtime, panggilan
audio/video, album berdua, surat digital, dan notifikasi yang tetap nyala
bahkan saat aplikasi di-kill — semuanya jalan di infrastruktur gratis tanpa
kartu kredit (Firebase Spark, Cloudinary unsigned, Cloudflare Workers free
tier, GitHub Actions).

```text
[ HP Kamu ] <==== WebRTC P2P ====> [ HP Dia ]
    |                                   |
    +---- Firestore (chat/presence) ----+
    +---- Cloudinary (media CDN) -------+
    |
    +---> Cloudflare Worker ---> FCM HTTP v1 ---> Notif (app killed pun tembus)
    |
    +---> GitHub Actions: build APK + release + deploy rules + deploy worker
```

---

## Fitur Utama

| Modul | Isi |
|---|---|
| Auth | Register/login email+password, foto profil saat daftar, self-heal dokumen user |
| Pairing | Kode undangan DYKAL-XXXX (24 jam, sekali pakai), kunci hanya berdua |
| Home | Hero couple, kartu anniversary dan ulang tahun, story ala WhatsApp dari album |
| Chat | Teks/foto/video, swipe-to-reply, voice note + waveform, stiker kustom terenkripsi, kamera in-app, presence online/typing/last-seen |
| Album | Album bersama, grid staggered, kompres WebP otomatis, shape foto kustom (bulat/love/star/hexagon) |
| Surat | Surat digital antar pasangan |
| Call | Audio+video WebRTC, 10 STUN + TURN fallback, riwayat panggilan, incoming call screen, floating bubble |
| Notifikasi | FCM + channel lokal, pengingat ultah, push saat app di-kill via Cloudflare Worker, preferensi notif per jenis |
| Updater | Banner update + changelog dari GitHub Release, unduh async, auto-install |
| Boot | Splash animasi (tap-to-skip), layar error informatif dengan tombol coba ulang |

---

## Arsitektur dan Teknologi

- Framework: Flutter 3.44.9, Dart >= 3.6 (Material 3, null safety)
- Backend realtime: Cloud Firestore, Security Rules hardened (rules auto-
  deploy dari repo)
- Auth: Firebase Auth email/password + sistem invite code privat
- Media: Cloudinary unsigned upload + kompresi WebP klien
- Panggilan: WebRTC peer connection + signaling Firestore + ICE STUN/TURN
- Push: Cloudflare Worker menandatangani JWT service account dan menembak
  FCM HTTP v1, dengan kunci bersama anti-abuse (DYKAL_PUSH_KEY)
- Enkripsi lokal: stiker dan media privat AES-256-GCM (format .webp.crypt15)
- Storage media ala WhatsApp: Android/media/com.dykal.app/Dykal/Media/
  (Images, Images/Sent (.nomedia), Images/Private, Video, Audio, Documents,
  Stickers)

## Pipeline Otomasi (GitHub Actions)

| Workflow | Tugas | Pemicu |
|---|---|---|
| Build DyKal APK | Flutter analyze + build APK split ABI | Push / PR ke main |
| Release DyKal APK | Build signed + GitHub Release + changelog otomatis | Push ke main |
| Deploy Firestore Rules | Deploy rules via Rules REST API (tanpa firebase-tools) | Perubahan firestore.rules |
| Deploy Cloudflare Worker | Sync 4 worker secret + wrangler deploy | Perubahan cloudflare/ |

Distribusi update ke pengguna berjalan dari GitHub Release: aplikasi memeriksa
rilis terbaru dan menampilkan banner update beserta changelog-nya.

## Design System

- Light: primary #FF6B8A (Soft Rose), background #FFF8F9 (Warm White)
- Dark (TikTok Soft Dark): #121212 matte, kartu #1F2029, teks muted #8A8B91
- Tipografi: Poppins (judul) + Plus Jakarta Sans (body) via google_fonts
- Komponen: DyKalSkeleton (shimmer adaptif), DyKalImage (smart cache),
  DyKalButton (state loading otomatis), bottom nav kustom seamless
- Splash: animasi ular-love ikonik + tap-to-skip + fade-out halus

## Kebijakan Izin Android (Play-Compliant)

Memakai RECORD_AUDIO, CAMERA, FOREGROUND_SERVICE_MICROPHONE/CAMERA/
MEDIA_PROJECTION, USE_FULL_SCREEN_INTENT, MANAGE_OWN_CALLS.
Sengaja menghapus seluruh izin GSM terlarang (READ_CALL_LOG, CALL_PHONE,
READ_PHONE_STATE, dan kawan-kawannya) demi lolos review Play Store.

## Build Lokal

```bash
flutter pub get
flutter analyze
flutter build apk --release --split-per-abi \
  --dart-define=DYKAL_PUSH_KEY=<kunci-worker>
```

Struktur kerja developer agent diatur di ATURAN.md dan PEMIKIRAN.md.

---

<p align="center">
  <sub>XYSTUDIO — dibuat dan dirawat oleh Kall bersama Arena Dev. Ruang kecil untuk dua orang, direkayasa dengan serius.</sub>
</p>
