# Live Photo — Fase 1 (rilis bersama Batch J)

Spek induk: `uploads/FITUR-LIVE-PHOTO.md`. Fase ini mengikuti roadmap Fase 1
persis: **Import MP4 -> trim slider -> cover -> preset -> SIMPAN VIDEO + SHARE**,
100% on-device (tanpa server transcode, Rp 0).

## Komponen

| Lapis | File | Tugas |
|---|---|---|
| Mesin native | `android/.../LivePhotoTool.kt` | Channel `dykal/livephoto`: `probe`, `cover`, `start`, `progress`, `cancel`. Media3 Transformer 1.4.1 (trim via `ClippingConfiguration`, skala via `Presentation.createForHeight(720)`, look via `RgbMatrix` matriks 4x4). Cover via `MediaMetadataRetriever` + `ColorMatrix` dari matriks yang sama -> cover & klip satu rasa. |
| Jembatan Dart | `lib/services/live_photo_tool.dart` | Kontrak channel + generator matriks preset (Hangat, CCD 2000an, Sepia, Dingin, Hitam Putih Pudar). |
| UI | `lib/screens/live_photo/live_photo_screen.dart` | Picker (`image_picker`), preview (`video_player`), `RangeSlider` trim maks 30 dtk, slider frame cover + pratinjau JPEG langsung, chip preset, progres %, hasil (ukuran MB). |
| Titik masuk | menu lampiran chat | Item baru "Live Photo" di `chat_screen._openAttachmentMenu` (ikon `motion_photos_on`). |

## Keputusan & alasan

- **Media3 Transformer, bukan FFmpegKit** — FFmpegKit retired (sesuai spek).
  Signature API diverifikasi dari source tag 1.4.1 (Listener `onError(Composition,
  ExportResult, ExportException)`, `getProgress(ProgressHolder)` main-thread).
- **Share lewat `share_plus` & simpan lewat `photo_manager.editor.saveVideo`**
  — dua-duanya sudah jadi dependensi (pola share disalin persis dari
  `fullscreen_media_viewer`). `gal` tidak jadi ditambah -> pubspec tetap ramping.
- **Preset = matriks 4x4 tunggal dari Dart** — dipakai video (RgbMatrix) dan
  cover (ColorMatrix 4x5 offset 0). Tambah preset baru tinggal tambah baris
  di `LivePhotoPreset.all`, native tidak perlu diubah.
- **Target kompresi**: tinggi 720 + H264/AAC; target spek <=8MB untuk 30 dtk.
  Verifikasi angka persisnya di HP nyata (bitrate encoder per-OEM beda).

## Checklist tes on-device (Fase 1)

- [ ] Pilih video 1+ menit -> trim ke 10 dtk -> hasil lancar diputar
- [ ] Video miring/vertikal tetap benar orientasinya (doctor: Transformer urus rotasi)
- [ ] Preset "Sepia"/"CCD" tampak sama di cover & klip hasil
- [ ] Hasil 30 dtk <=8MB (atau catat ukuran sebenarnya untuk kalibrasi)
- [ ] "Simpan Video" muncul di galeri; "Bagikan" ke WA/TikTok jalan
- [ ] Batal: tutup layar saat proses -> tidak ada job zombie (`cancel` di dispose)

## Belum masuk fase ini (roadmap)

- **Fase 2**: writer Motion Photo (JPG+XMP GCamera+append MP4) -> badge "LIVE"
  otomatis di Google Photos/Samsung Gallery.
- **Fase 3**: kirim ke pasangan (enkripsi E2EE + notif worker) + tahan-untuk-putar di chat.
- **Fase 4**: preset maker (LUT, grain, light leak, cap tanggal).
- **Fase 5**: iOS PhotoKit pair (butuh akun Apple Developer).
