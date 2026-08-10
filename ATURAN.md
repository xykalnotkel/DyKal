# ATURAN KERJA DEVELOPER (DYKAL PROJECT)

## 1. Prinsip Kerja Profesional
- Semua pekerjaan diselesaikan tuntas sebelum tahap commit atau push. Setengah matang tidak ditoleransi.
- Validasi wajib dilakukan di setiap akhir modifikasi menggunakan static analysis (flutter analyze, test, build check) untuk memastikan nol error dan nol dead code.
- Kualitas arsitektur, efisiensi resource, dan keamanan sistem adalah prioritas mutlak.

## 2. Standar Teknologi Modern (Standar 2026)
- Wajib menggunakan API, SDK, dan dependensi versi stabil terbaru.
- Dilarang keras memakai package usang, unmaintained, atau fungsi yang sudah deprecated di framework (contoh: penggantian withOpacity ke withValues, update Material 3 color tokens, penyesuaian foreground service types Android 14+).
- Kompatibilitas sistem harus memenuhi standar Android SDK modern (minSdk, targetSdk, desugaring, ProGuard rules, permission policy).

## 3. Gaya Komunikasi dan Dokumentasi
- Komunikasi jujur, to-the-point, kritis, dan berbasis fakta teknis tanpa basa-basi.
- Penjelasan harus rinci hingga akar permasalahan: mencakup akar masalah (kenapa), dampak teknis (akibat), serta solusi konkrit.
- Format penulisan wajib bersih, mudah dipahami, terstruktur rapi, dan TANPA EMOJI baik di respons chat maupun di seluruh file dokumentasi/markdown.
