# Setup Backend + Build APK via GitHub Actions

## Status: FRONTEND 100% SELESAI — Tinggal 5 Menit Setup Backend

Semua UI, logic, ilustrasi, overlay pojok sudah jadi. Yang belum cuma **koneksi backend** (Firebase + Cloudinary). Tanpa itu APK tetap bisa di-build tapi data tidak akan tersimpan.

---

### 1. Setup Firebase (2 menit) — WAJIB

1. Buka https://console.firebase.google.com → Create Project `dykal`
2. Aktifkan:
   - Authentication → Email/Password → Enable
   - Firestore Database → Create → Start in **Test Mode** (biar gampang)
   - Cloud Messaging → Enable
   - **JANGAN** aktifkan Storage (yang minta CC)
3. Project Settings → General → Your apps → Android → Add App
   - Package name: `com.dykal.app` (sesuaikan dengan `android/app/build.gradle`)
   - Download `google-services.json`
4. Taruh file di `android/app/google-services.json` di laptop lu

### 2. Setup Cloudinary (1 menit) — WAJIB

1. Daftar https://cloudinary.com (email doang, NO CC)
2. Dashboard → Copy **Cloud Name** (contoh `dxxxxx123`)
3. Settings → Upload → Upload presets → **Add upload preset**
   - Name: `dykal_unsigned`
   - Signing Mode: `Unsigned`
   - Folder: `dykal`
   - Save
4. Edit `lib/config/app_constants.dart` di laptop:
```dart
static const cloudinaryCloudName = "dxxxxx123"; // ganti
static const cloudinaryUploadPreset = "dykal_unsigned";
```

### 3. Push ke GitHub + Set Secrets untuk Actions

```bash
git init
git add .
git commit -m "DyKal initial"
git branch -M main
git remote add origin https://github.com/username/dykal.git
git push -u origin main
```

Di GitHub → Settings → Secrets and variables → Actions → **New repository secret**:

| Name | Value | Cara buat |
| :--- | :--- | :--- |
| `GOOGLE_SERVICES_JSON_BASE64` | isi file `google-services.json` dalam base64 | `base64 -w 0 android/app/google-services.json` (Linux/Mac) atau `certutil -encode ...` di Windows lalu copy 1 baris |
| `CLOUDINARY_CLOUD_NAME` | `dxxxxx123` | dari Cloudinary dashboard |

> Jika tidak set secrets, workflow tetap build APK tapi Firebase tidak connect (app jalan offline).

### 4. Build Otomatis di GitHub Actions

File workflow sudah ada di `.github/workflows/build-apk.yml`

- Setiap `git push` ke `main` → otomatis build
- Atau manual: GitHub → Actions → Build DyKal APK → Run workflow

Hasil APK:
- `app-arm64-v8a-release.apk` (paling kecil, untuk HP modern)
- `app-release.apk` (universal, bisa install di semua HP)
- Download di **Actions → Artifacts**

### 5. Build Lokal (jika mau)

```bash
flutter pub get
flutter build apk --release --split-per-abi
# APK di build/app/outputs/flutter-apk/
```

---

### Ilustrasi & Overlay Pojok Grid

- `album_overlay.webp` sekarang dipakai di **4 pojok grid** sebagai stiker bulat putih:
  - Kiri atas: heart pink 22px
  - Kanan atas: sparkle kuning 16px
  - Kiri bawah: star ungu 14px
  - Kanan bawah: heart pink 18px
- Plus header overlay 86x86 dan footer 72px
- Semua WebP transparan, no emoji, icons Phosphor rounded Border→Fill

Sudah siap 100% — tinggal setup 2 secret di atas, push, download APK dari Actions.
