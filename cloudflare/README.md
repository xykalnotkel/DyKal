# DyKal Push Worker (Cloudflare) — push background GRATIS tanpa Blaze

Worker ini mengirim push FCM ke device pasangan saat ada **chat baru** atau
**panggilan masuk** (termasuk saat app di-kill), tanpa Cloud Functions / Blaze.

## Cara kerja sekarang (otomatis via GitHub Actions)

Worker **ter-deploy & tersinkron otomatis** tiap folder `cloudflare/` berubah di
branch `main` (workflow "Deploy Cloudflare Worker"). Termasuk sinkron 4 secret
worker ini dari GitHub Secrets (sudah di-set, tidak perlu diapa-apakan lagi):

| Secret worker | Sumber |
|---|---|
| `FCM_PROJECT_ID` | service account JSON Firebase |
| `FCM_CLIENT_EMAIL` | service account JSON Firebase |
| `FCM_PRIVATE_KEY` | service account JSON Firebase |
| `DYKAL_PUSH_KEY` | kunci anti-spam (disuntik juga ke APK via `--dart-define` saat build CI) |

## Yang harus kamu lakukan SEKALI (±2 menit)

1. **dash.cloudflare.com** → My Profile → **API Tokens** → **Create Token** →
   template **"Edit Cloudflare Workers"** → Continue → Create → copy token.
2. GitHub repo → Settings → **Secrets and variables → Actions** → New repository secret:
   - Nama: `CLOUDFLARE_API_TOKEN`
   - Isi: token dari langkah 1
3. Tab **Actions** → "Deploy Cloudflare Worker" → **Run workflow**. Selesai ✅
   (push berikutnya yang menyentuh folder ini akan deploy sendiri.)

## Catatan penting

- `wrangler.toml` memakai `name = "dykal"` — HARUS sama dengan URL worker yang
  dipanggil app di `lib/services/push_service.dart`
  (`https://dykal.<subdomain>.workers.dev`). Salah nama = bikin worker baru yang
  tidak dipakai app.
- Setelah `DYKAL_PUSH_KEY` aktif, worker HANYA menerima request yang membawa
  kunci. Kunci mulai tertanam di APK mulai v1.1.4 (via `--dart-define`), jadi
  pastikan kedua HP ter-update supaya push tidak tertolak.
- Cara manual (opsional): `npm i -g wrangler` → `wrangler login` →
  `wrangler deploy` dari folder ini. Hasilnya sama.
- Notif muncul saat app di-kill; tap notif membuka app. Layar incoming-call
  full-screen otomatis bisa ditambah nanti (butuh FCM data-only + handler).

## Tes

- Pasangan kill app-nya → kamu kirim chat → dia dapat notif ✅
- Kamu nelpon → dia dapat notif panggilan (basi otomatis setelah 45 detik) ✅
