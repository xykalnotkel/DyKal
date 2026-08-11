# ATURAN KERJA DEVELOPER (DYKAL PROJECT / XYSTUDIO)

Kontrak kerja antara owner (Kall) dan developer agent. File ini hukumnya
di atas kebiasaan umum; kalau ada yang bentrok, ikuti file ini.

---

## 1. Disiplin Git (ATURAN PALING PENTING)

- DILARANG PUSH TANPA IZIN eksplisit dari Kall. Titik.
- COMMIT LOKAL diperbolehkan dan justru WAJIB dilakukan rutin, supaya hasil
  kerja selalu tersimpan aman dulu sebelum ada kata "push".
- Alur baku: kerja -> commit lokal (pesan rapi & jelas) -> lapor -> tunggu
  izin -> baru push ke remote.
- Setiap commit lokal dilaporkan ke Kall: apa isinya, file apa yang berubah,
  dan kenapa.

## 2. Prinsip Kerja Profesional

- Semua pekerjaan diselesaikan tuntas sebelum tahap commit. Setengah matang
  tidak ditoleransi.
- Validasi wajib di setiap akhir modifikasi: static analysis (flutter
  analyze), build check, dan test bila ada. Nol error, nol dead code.
- Kualitas arsitektur, efisiensi resource, dan keamanan sistem adalah
  prioritas mutlak.

## 3. Standar Teknologi Modern (Standar 2026)

- Wajib memakai API, SDK, dan dependensi versi stabil terbaru.
- Dilarang keras package usang, unmaintained, atau API deprecated
  (contoh: withValues menggantikan withOpacity, token warna Material 3,
  foreground service types Android 14+).
- Kompatibilitas mengikuti SDK Android modern (minSdk 24, targetSdk terbaru,
  desugaring, ProGuard rules, permission policy Google Play).

## 4. Gaya Komunikasi dan Dokumentasi

- TANPA EMOJI. Berlaku di pesan chat, komentar kode yang terlihat user,
  dan seluruh file markdown/dokumentasi tanpa kecuali.
- Komunikasi jujur, to-the-point, kritis, berbasis fakta teknis, tanpa
  basa-basi. Bahasa gaul boleh, sopan tetap jalan.
- Penjelasan wajib sampai ke AKAR: kenapa masalahnya muncul, apa dampak
  teknisnya, lalu solusi konkretnya. Tidak berhenti di permukaan.
- Struktur tulisan rapi: heading, tabel, dan blok kode bila perlu.

## 5. README.md

- Wajib estetik, bebas emoji, dan mengusung wall of badges (status build
  CI, versi release, stack teknologi, platform).
- README adalah wajah publik repo: harus banggain-able. Setiap fitur besar
  baru -> README ikut diperbarui.

---

Terakhir diperbarui: 2026-08-11 oleh Arena Dev bersama Kall.
