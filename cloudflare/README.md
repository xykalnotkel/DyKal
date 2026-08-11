# DyKal Push Worker (Cloudflare) — push background GRATIS tanpa Blaze

Worker ini mengirim push FCM ke device pasangan saat ada **chat baru** atau
**panggilan masuk** (termasuk saat app di-kill), tanpa Cloud Functions / Blaze.

## Endpoint resmi (custom domain XYSTUDIO)

| URL | Fungsi |
|---|---|
| `https://push.xystudio.my.id` | Dipakai app (`lib/services/push_service.dart`) |
| `https://api.xystudio.my.id` | Nempel ke worker yang sama — cadangan endpoint masa depan |
| `https://dykal.akuntiktok76y.workers.dev` | Route lama, **SENGAJA tetap hidup**: APK lama masih memanggilnya. Jangan pernah dimatikan |

Custom domain adalah konfigurasi level akun Cloudflare (Settings worker >
Domains & Routes) — TIDAK tertulis di `wrangler.toml`, jadi deploy ulang
tidak akan menghapusnya. TLS otomatis (Universal SSL), tanpa biaya.

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

## Lapisan keamanan (sesuai KEAMANAN.md)

Status setelah hardening fase-1 (2026-08-11) — semuanya gratis:

| # | Fitur | Status |
|---|---|---|
| 1 | Secrets terenkripsi di worker | AKTIF (4 secret via CI) |
| 2 | Auth API key `x-dykal-key` | AKTIF — salah key -> 401 |
| 3 | Rate limit 30 req/menit/IP via KV `dykal-kv` | AKTIF — teruji live: request ke-31,32,33 -> 429 |
| 4 | Validasi + whitelist input | AKTIF — token dicek pola, title/body dipotong, field asing dibuang, `data` maks 12 key scalar |
| 5 | CORS diputus total | AKTIF — tanpa header ACAO, preflight -> 403 (API memang bukan untuk browser) |
| 8 | HTTPS-only + HSTS | AKTIF (header `strict-transport-security` di semua response) |
| 9 | DDoS bawaan Cloudflare | AKTIF |
| 11 | FCM HTTP v1 resmi | AKTIF |
| 12 | Cache access token OAuth di KV | AKTIF (TTL ~59 menit dengan margin) |
| 13 | Security headers + rotasi secret | AKTIF (nosniff, no-store, no-referrer; rotasi = `wrangler secret put`) |
| 6 | Turnstile / Bot Fight Mode | OPSIONAL — relevan kalau nanti ada endpoint yang dipanggil browser/publik |
| 7 | Registry token di D1 (anti spam ke token liar) | FASE 2 — butuh database D1 (gratis) |
| 10 | Audit log notif di D1 | FASE 2 — bareng #7 |

Kuota gratis yang relevan: Worker 100rb req/hari; KV 100rb baca + 1rb tulis/hari.
Rate limit & cache OAuth menulis 1-2 KV per request — aplikasi pasangan jauh di
bawah kuota. Rate limit sengaja **fail-open**: kalau KV gangguan, request tetap
dilayani (chat pasangan lebih penting daripada counter).

## Catatan penting

- `wrangler.toml` memakai `name = "dykal"` dan binding `[[kv_namespaces]]` ke
  namespace `dykal-kv`. Jangan hapus binding: deploy CI berikutnya akan ikut
  melepasnya dari worker dan rate limit mati.
- Setelah `DYKAL_PUSH_KEY` aktif, worker HANYA menerima request yang membawa
  kunci. Kunci tertanam di APK sejak v1.1.4 (via `--dart-define`), jadi
  pastikan kedua HP ter-update supaya push tidak tertolak.
- Cara manual (opsional): `npm i -g wrangler` -> `wrangler login` ->
  `wrangler deploy` dari folder ini (butuh Node >= 22). Hasilnya sama.
- Notif muncul saat app di-kill; tap notif membuka app. Layar incoming-call
  full-screen otomatis bisa ditambah nanti (butuh FCM data-only + handler).

## Tes

Live-tested 2026-08-11: health GET ketiga route 200 OK; POST tanpa key -> 401
dengan header keamanan lengkap; OPTIONS -> 403; burst 33 request -> 30x401 lalu
429 (retry-after 60).

Manual: pasangan kill app-nya -> kamu kirim chat -> dia dapat notif.
Kamu nelpon -> dia dapat notif panggilan (basi otomatis setelah 45 detik).
