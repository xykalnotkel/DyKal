# DyKal Push Worker (Cloudflare) — push background GRATIS tanpa Blaze

Worker ini dikirim push FCM ke device pasangan pas ada **chat baru** atau **panggilan masuk** (termasuk saat app di-kill), tanpa perlu Cloud Functions / Blaze.

## Setup (sekali doang)

### 1. Buat akun & deploy Worker
- Daftar [cloudflare.com](https://cloudflare.com) (gratis).
- Install wrangler: `npm i -g wrangler` lalu `wrangler login`.
- Di folder `cloudflare/`: `wrangler deploy`.
- Catat URL Worker-nya, misal `https://dykal-push.<sub>.workers.dev`.

### 2. Ambil Service Account Key Firebase
- Firebase Console → **Project settings** → **Service accounts** → **Generate new private key** → simpan JSON.
- Dari JSON itu ambil 3 nilai: `project_id`, `client_email`, `private_key`.

### 3. Set secret di Worker
Di folder `cloudflare/`, jalankan 3 perintah (paste nilai dari JSON):
```
wrangler secret put FCM_PROJECT_ID
wrangler secret put FCM_CLIENT_EMAIL
wrangler secret put FCM_PRIVATE_KEY
```
(`private_key` di-paste utuh termasuk `-----BEGIN PRIVATE KEY-----` dst.)

### 4. Masukkan URL Worker ke app
Edit `lib/services/push_service.dart` → ganti `workerUrl` dengan URL Worker-mu (langkah 1). Lalu build ulang.

## Tes
- Pasangan tutup app-nya (kill).
- Kamu kirim chat → dia dapat notif "pesan baru". ✅
- Kamu nelpon → dia dapat notif "panggilan masuk". ✅

> Catatan: notif ini MUNCUL saat app ditutup, tapi belum otomatis membuka layar telepon full-screen (butuh layar incoming-call khusus — bisa ditambah nanti). Tap notif tetap membuka app.
