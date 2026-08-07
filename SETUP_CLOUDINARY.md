# Cloudinary Setup NO CC (2 Menit)

Karena Firebase Storage di Indonesia sekarang wajib verifikasi CC walau gratis, kita pakai Cloudinary.

### Langkah:

1. Buka cloudinary.com > Sign Up Free (Email saja, NO CC)
   - Free: 25GB Images/Video + 25GB Bandwidth + 1GB Video Transcode

2. Setelah login, di Dashboard atas ada **Cloud Name** `dxxxxx` — catat.

3. Ke **Settings (gear icon) > Upload > Upload presets > Add upload preset**
   - Preset name: `dykal_unsigned`
   - Signing Mode: **Unsigned**
   - Folder: `dykal`
   - Unique filename: ON
   - Overwrite: OFF
   - Save

4. Di `lib/config/app_constants.dart` ganti:
```dart
static const cloudinaryCloudName = "dxxxxx"; // punya lu
static const cloudinaryUploadPreset = "dykal_unsigned";
```

5. Test upload: di Album > + > pilih foto > otomatis ke https://res.cloudinary.com/dxxxxx/image/upload/f_auto,q_auto/dykal/album/xxx.webp

### Kenapa WebP?
- File 40% lebih kecil dari JPG, tapi kualitas sama
- Support transparan (ilustrasi tanpa background)
- Diupload otomatis jadi `f_auto,q_auto` = Cloudinary otomatis kirim WebP/AVIF ke device yang support

### Limit Aman untuk 2 Orang:
- Foto per hari 5 foto x 2MB (WebP jadi ~0.8MB) = 4MB/hari
- 25GB = bisa untuk **17 tahun** wkwk
