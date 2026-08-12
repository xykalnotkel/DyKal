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

## Sudah masuk (Batch K) — Fase 2

- **Writer Motion Photo** (`lib/services/motion_photo_writer.dart`, pure Dart):
  rangkai JPEG + APP1 XMP `GContainer` (`GCamera:MotionPhoto=1`, Item:Length =
  ukuran MP4) + byte MP4 di ekor. Aritmetika segmen JPEG diverifikasi via
  uji Python (3 kasus: ada APP0, tanpa APPn, APP1 eksisting).
- Tombol **"Simpan sebagai Live Photo"** di kartu hasil -> galeri (badge LIVE
  di Google Photos/Samsung Gallery; galeri lain tetap menampilkan foto).
- Timestamp presentasi cover mengikuti konvensi Google (relatif ke akhir klip).

## Checklist tes on-device

- [ ] Pilih video 1+ menit -> trim ke 10 dtk -> hasil lancar diputar
- [ ] Video miring/vertikal tetap benar orientasinya
- [ ] Preset "Sepia"/"CCD" tampak sama di cover & klip hasil
- [ ] Hasil 30 dtk <=8MB (atau catat ukuran sebenarnya untuk kalibrasi)
- [ ] "Simpan Video" muncul di galeri; "Bagikan" ke WA/TikTok jalan
- [ ] "Simpan sebagai Live Photo" -> badge motion-photo MUNCUL di Google Photos
- [ ] File yang sama dibuka di galeri lain -> tampil sebagai foto diam
- [ ] Batal: tutup layar saat proses -> tidak ada job zombie (`cancel` di dispose)

## Belum masuk (roadmap)

- **Fase 3**: kirim ke pasangan (enkripsi E2EE + notif worker) + tahan-untuk-putar di chat.
- **Fase 4**: preset maker (LUT, grain, light leak, cap tanggal).
- **Fase 5**: iOS PhotoKit pair (butuh akun Apple Developer).
