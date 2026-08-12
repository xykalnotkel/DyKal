/**
 * DyKal Push Worker (Cloudflare)
 * --------------------------------
 * Mengirim FCM push (HTTP v1) ke device pasangan — dipanggil app DyKal
 * saat ada pesan/chat baru atau panggilan masuk. Gratis (Worker free tier).
 *
 * Custom domain (dua-duanya nempel ke worker ini, setara):
 *   https://push.xystudio.my.id  -> dipakai app
 *   https://api.xystudio.my.id   -> dicadangkan untuk endpoint masa depan
 * Route workers.dev (dykal.akuntiktok76y.workers.dev) SENGAJA tetap hidup:
 * APK lama masih memanggilnya — mematikannya = bunuh notif user lama.
 *
 * Secrets (set via dashboard atau `wrangler secret put`):
 *   FCM_PROJECT_ID    -> Project ID Firebase (Console > Project settings)
 *   FCM_CLIENT_EMAIL  -> client_email dari service account JSON
 *   FCM_PRIVATE_KEY   -> private_key dari service account JSON (PEM, biarkan \n)
 *   DYKAL_PUSH_KEY    -> kunci bersama dgn app (disuntik via --dart-define saat build)
 *
 * Binding KV (wrangler.toml): DYKAL_KV -> rate limit + cache token OAuth.
 *
 * Lapisan keamanan (sesuai KEAMANAN.md):
 *   #2  auth header x-dykal-key        #3  rate limit 30 req/menit/IP (KV)
 *   #4  validasi + whitelist input     #5  CORS diputus total (API non-browser)
 *   #12 cache access token di KV       #13 security headers + rotasi via wrangler secret
 */

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const RL_LIMIT = 30;        // request per menit per IP
const RL_WINDOW_MS = 60000; // jendela hitung 1 menit

export default {
  async fetch(request, env) {
    // #5 CORS: mati total. API ini hanya dipanggil app (bukan browser), jadi
    // kita tidak pernah mengirim Access-Control-Allow-Origin. Preflight browser
    // dari situs orang lain dijawab tegas 403.
    if (request.method === 'OPTIONS') return json({ error: 'CORS dinonaktifkan: API ini bukan untuk browser' }, 403);

    if (request.method === 'GET') return json({ ok: true, service: 'dykal-push' });
    if (request.method !== 'POST') return json({ error: 'use POST' }, 405);

    // #3 RATE LIMIT duluan (lebih murah dari auth) — juga melindungi endpoint
    // dari brute-force API key. Fail-open dengan header penanda kalau KV gangguan.
    if (await rateLimited(env, request)) {
      return json({ error: 'terlalu banyak request, coba lagi sebentar' }, 429, { 'retry-after': '60' });
    }

    // #2 AUTH: kalau DYKAL_PUSH_KEY di-set, request WAJIB bawa header cocok.
    if (env.DYKAL_PUSH_KEY && request.headers.get('x-dykal-key') !== env.DYKAL_PUSH_KEY) {
      return json({ error: 'unauthorized' }, 401);
    }

    let body;
    try { body = await request.json(); } catch { return json({ error: 'bad json' }, 400); }

    // #4 VALIDASI + WHITELIST: field asing dibuang, string dipotong, token dicek polanya.
    const v = sanitizeBody(body);
    if (v.error) return json({ error: v.error }, 400);
    const { token, topic, title, msgBody, data, type, dataOnly } = v.value;

    // Diagnostik: pastikan 3 secret sudah ter-set
    if (!env.FCM_PROJECT_ID || !env.FCM_CLIENT_EMAIL || !env.FCM_PRIVATE_KEY) {
      return json({ error: 'Secret Cloudflare belum lengkap', set: { FCM_PROJECT_ID: !!env.FCM_PROJECT_ID, FCM_CLIENT_EMAIL: !!env.FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY: !!env.FCM_PRIVATE_KEY } }, 400);
    }

    try {
      const accessToken = await getAccessToken(env);
      const isCall = type === 'call';
      const isCancel = type === 'call_cancel';
      const isUpdate = type === 'update';
      // Batch D: channel notif panggilan dipisah audio vs video — user bisa
      // bedakan dering/getar keduanya di pengaturan sistem Android.
      const callChannel = data && data.callType === 'audio' ? 'dykal_call_audio' : 'dykal_call_video';
      const targetChannel = (isCall || isCancel) ? callChannel : (isUpdate ? 'dykal_update' : 'dykal_chat');
      const message = {
        // Target: topic whitelist (broadcast) ATAU token device — tidak dua2nya.
        ...(topic ? { topic } : { token }),
        // SPEK v2 #4 (Batch G): data-only bila app pengirim menandai dataOnly
        // (device tujuan sudah notifCap v2 = bisa merender MessagingStyle
        // sendiri di semua state). App lama tetap menerima key notification
        // (hybrid) supaya notif tidak hilang saat app di-kill.
        // call_cancel SELALU data-only: murni sinyal kontrol penghenti dering.
        ...(dataOnly ? {} : { notification: { title, body: msgBody || '' } }),
        data,
        android: {
          priority: 'high',
          // collapse_key: banyak pesan beruntun -> 1 notif terbaru (anti numpuk).
          // call_cancel memakai key call AGAR pesan batal "menimpa" panggilan
          // yang masih mengantre (bukan numpuk dua-duanya).
          collapse_key: (isCall || isCancel) ? 'dykal_call' : (isUpdate ? 'dykal_update' : 'dykal_chat'),
          // ttl: panggilan basi 45 dtk; sinyal batal hanya berguna 10 dtk;
          // chat bertahan 24 jam kalau HP pasangan offline.
          ttl: isCancel ? '10s' : (isCall ? '45s' : '86400s'),
          // icon: ic_notification = siluet hati resmi (drawable), BUKAN ic_launcher
          // (launcher icon ber-latar putih jadi kotak buram kalau dipaksa jadi icon status bar)
          // PENTING (FIX FCM dataOnly): saat dataOnly = true, JANGAN kirim block
          // android.notification! Jika android.notification ada, Google Play Services
          // menganggap pesan ini sebagai Notification Message dan TIDAK memanggil
          // firebaseMessagingBackgroundHandler untuk membuat MessagingStyle kustom!
          ...(dataOnly ? {} : {
            notification: { icon: 'ic_notification', color: '#FF6B8A', channel_id: targetChannel, sound: 'default', visibility: 'PRIVATE', notification_count: 1 }
          }),
        },
        apns: { payload: { aps: { sound: 'default' } } },
      };
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${env.FCM_PROJECT_ID}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message }),
      });
      // Passthrough respons FCM, tapi tetap lewat header keamanan kita.
      return new Response(await r.text(), { status: r.status, headers: baseHeaders() });
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },
};

/* ---------------- validasi & keamanan ---------------- */

// #4 Whitelist ketat. Return {error} atau {value}.
function sanitizeBody(body) {
  if (!body || typeof body !== 'object') return { error: 'bad json' };
  const { token, title, body: msgBodyRaw, data: dataRaw, type: typeRaw, topic: topicRaw, dataOnly: dataOnlyRaw } = body;

  // Batch: dukung TARGET TOPIC (whitelist ketat) untuk broadcast CI, mis.
  // notif update realtime ke semua device. Kalau topic dipakai, token diabaikan.
  let topic = null;
  if (typeof topicRaw === 'string' && ['app_updates'].includes(topicRaw)) {
    topic = topicRaw;
  }
  if (!topic && (typeof token !== 'string' || token.length < 70 || token.length > 400 || !/^[A-Za-z0-9_\-.:%]+$/.test(token))) {
    return { error: 'token tidak valid' };
  }
  if (typeof title !== 'string' || title.trim() === '') return { error: 'title required' };

  // type: whitelist, selain itu dipaksa 'chat' (bukan ditolak, demi kompatibilitas app lama)
  const type = ['chat', 'call', 'call_cancel', 'letter', 'update'].includes(typeRaw) ? typeRaw : 'chat';

  // data: hanya object polos, maks 12 key, key alfanumerik, nilai scalar -> string maks 200 char
  const data = {};
  if (dataRaw && typeof dataRaw === 'object' && !Array.isArray(dataRaw)) {
    const keys = Object.keys(dataRaw).slice(0, 12);
    for (const k of keys) {
      if (!/^[A-Za-z0-9_]{1,32}$/.test(k)) continue;
      const val = dataRaw[k];
      if (val === null || ['string', 'number', 'boolean'].includes(typeof val)) {
        data[k] = String(val).slice(0, 200);
      }
    }
  }
  data.type = type;

  return {
    value: {
      token: topic ? '' : token,
      topic,
      title: title.slice(0, 120),
      msgBody: typeof msgBodyRaw === 'string' ? msgBodyRaw.slice(0, 500) : '',
      data,
      type,
      // dataOnly hanya true bila benar-benar boolean true (bukan truthy string).
      dataOnly: dataOnlyRaw === true || type === 'call_cancel',
    },
  };
}

// #3 Rate limit: counter per IP per menit di KV. Fail-open saat KV error.
async function rateLimited(env, request) {
  if (!env.DYKAL_KV) return false;
  try {
    const ip = request.headers.get('cf-connecting-ip') || 'anon';
    const slot = Math.floor(Date.now() / RL_WINDOW_MS);
    const key = `rl:${ip}:${slot}`;
    const n = parseInt((await env.DYKAL_KV.get(key)) || '0', 10) + 1;
    await env.DYKAL_KV.put(key, String(n), { expirationTtl: 120 });
    return n > RL_LIMIT;
  } catch (_) {
    return false;
  }
}

// #13 Header keamanan standar di SEMUA response. Tanpa ACAO = CORS terkunci.
function baseHeaders() {
  return {
    'content-type': 'application/json',
    'x-content-type-options': 'nosniff',
    'cache-control': 'no-store',
    'referrer-policy': 'no-referrer',
    'strict-transport-security': 'max-age=31536000',
  };
}
function json(o, s = 200, extra = {}) {
  return new Response(JSON.stringify(o), { status: s, headers: { ...baseHeaders(), ...extra } });
}

/* ---------------- OAuth2 service account -> FCM v1 ---------------- */

// #12 Access token (umur 1 jam) di-cache di KV: hemat latensi & kuota Google.
async function getAccessToken(env) {
  const now = Date.now();
  if (env.DYKAL_KV) {
    try {
      const hit = await env.DYKAL_KV.get('oauth:access_token', { type: 'json' });
      if (hit && hit.token && hit.exp > now + 60000) return hit.token;
    } catch (_) { /* cache gagal -> minta token baru saja */ }
  }

  const sec = Math.floor(now / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = { iss: env.FCM_CLIENT_EMAIL, scope: SCOPE, aud: 'https://oauth2.googleapis.com/token', iat: sec, exp: sec + 3600, sub: env.FCM_CLIENT_EMAIL };
  const enc = (o) => base64url(JSON.stringify(o));
  const unsigned = `${enc(header)}.${enc(claim)}`;
  const key = await importPkcs8(env.FCM_PRIVATE_KEY);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${bufToB64url(sig)}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const t = await r.json();
  if (!t.access_token) throw new Error('gagal minta access token: ' + JSON.stringify(t).slice(0, 200));

  if (env.DYKAL_KV) {
    try {
      // Simpan dengan margin 1 menit sebelum kadaluarsa asli
      await env.DYKAL_KV.put('oauth:access_token', JSON.stringify({ token: t.access_token, exp: now + (t.expires_in || 3600) * 1000 - 60000 }), { expirationTtl: 3540 });
    } catch (_) { /* abaikan */ }
  }
  return t.access_token;
}

function base64url(s) { return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }
function bufToB64url(buf) {
  const bytes = new Uint8Array(buf);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64ToBuf(b64) {
  const s = atob(b64.replace(/-/g, '+').replace(/_/g, '/'));
  const bytes = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) bytes[i] = s.charCodeAt(i);
  return bytes;
}
async function importPkcs8(pem) {
  const contents = String(pem).replace(/\\n/g, '\n').replace('-----BEGIN PRIVATE KEY-----', '').replace('-----END PRIVATE KEY-----', '').replace(/\s+/g, '');
  const der = b64ToBuf(contents);
  return crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}
