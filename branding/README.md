# DyKal Brand Kit

Semua turunan resmi dari satu master: `assets/logo/dykal_launcher.png`.
Regenerasi semuanya sekaligus: `python3 gen_brand.py` (script ada di workspace dev,
butuh `Pillow`, `numpy`, `vtracer`).

## Aturan utama

- Latar putih master **sudah dicabut** untuk semua turunan in-app. Alasannya:
  UI DyKal punya custom background sendiri (gradient pink di splash/mini-boot),
  jadi logo harus transparan. Versi ber-latar hanya untuk kebutuhan yang memang
  menolak transparan (lihat tabel).
- Folder `branding/` **tidak dibundel ke APK** (tidak dideklarasikan di pubspec).
  Murni kit pemasaran/web — nol byte di ukuran APK.

## Isi kit

| File | Format | Latar | Fungsi |
|---|---|---|---|
| `ico/dykal.ico` | ICO (16-256px multi-size) | Transparan | Favicon Windows/legacy, file associaton |
| `favicon/favicon-16.png` / `favicon-32.png` | PNG | Transparan | Favicon browser modern |
| `favicon/apple-touch-icon.png` | PNG 180 | Pink #FFE9EE | iOS home screen (Apple menolak transparan: dibuat hitam, makanya di-flatten) |
| `svg/dykal_logo.svg` | SVG vektor warna | Putih | Web/print, skala tak terbatas tanpa pecah (hasil trace vtracer, ~588 KB) |
| `svg/dykal_logo_silhouette.svg` | SVG vektor monokrom | Transparan | **Sumber desain icon notif** — monokrom karena status bar Android selalu me-tint icon kecil jadi satu warna |
| `png/dykal_logo_bg_pink.png` | PNG 1024 | Pink #FFE9EE | Versi "background default" brand |
| `png/play_store_icon.png` | PNG 512 | Pink #FFE9EE | Hi-res icon Google Play |
| `png/notification_silhouette.png` | PNG 512 | Transparan | Preview bentuk siluet untuk dicek manusia |
| `social/og_image.png` | PNG 1200x630 | Gradient brand | Open Graph/social preview repo & link share |

## Icon notifikasi push (rantai lengkapnya)

1. Desain: `svg/dykal_logo_silhouette.svg` (ditelusur dari alpha logo transparan).
2. Runtime Android: `android/app/src/main/res/drawable/ic_notification.xml`
   (VectorDrawable 24dp, fill putih, fillType evenOdd agar lubang hati tembus).
3. Fallback FCM: `AndroidManifest.xml` set `default_notification_icon` +
   `default_notification_color` (`@color/dykal_brand` = #FF6B8A).
4. Payload worker: `cloudflare/worker.js` mengirim `icon: 'ic_notification'` +
   `color: '#FF6B8A'` di kanal `android.notification`.
5. Notif lokal: `fcm_service.dart` & `birthday_service.dart` memakai
   `@drawable/ic_notification` di `AndroidInitializationSettings`.

Kenapa bukan `ic_launcher`? Launcher icon 1024px ber-latar putih diperas ke 24dp
oleh sistem = kotak putih buram di status bar. Icon notif wajib siluet transparan.
