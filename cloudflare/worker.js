/**
 * DyKal Push Worker (Cloudflare)
 * --------------------------------
 * Mengirim FCM push (HTTP v1) ke device pasangan — dipanggil app DyKal
 * saat ada pesan/chat baru atau panggilan masuk. Gratis (Worker free tier).
 *
 * Secrets (set via dashboard atau `wrangler secret put`):
 *   FCM_PROJECT_ID    -> Project ID Firebase (Console > Project settings)
 *   FCM_CLIENT_EMAIL  -> client_email dari service account JSON
 *   FCM_PRIVATE_KEY   -> private_key dari service account JSON (PEM, biarkan \n)
 *
 * Deploy: lihat README.md di folder ini.
 */

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

export default {
  async fetch(request, env) {
    if (request.method === 'GET') return json({ ok: true, service: 'dykal-push' });
    if (request.method !== 'POST') return json({ error: 'use POST' }, 405);

    let body;
    try { body = await request.json(); } catch { return json({ error: 'bad json' }, 400); }
    const { token, title, body: msgBody, data, type } = body || {};
    if (!token || !title) return json({ error: 'token & title required' }, 400);

    try {
      const accessToken = await getAccessToken(env);
      const isCall = type === 'call';
      const message = {
        token,
        notification: { title, body: msgBody || '' },
        data: normalizeData(data),
        android: {
          priority: 'high',
          notification: { channel_id: isCall ? 'dykal_call' : 'dykal_chat', priority: isCall ? 'max' : 'high', sound: 'default', visibility: 'PRIVATE', default_sound: true },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      };
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${env.FCM_PROJECT_ID}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message }),
      });
      return new Response(await r.text(), { status: r.status, headers: { 'content-type': 'application/json' } });
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },
};

function json(o, s = 200) {
  return new Response(JSON.stringify(o), { status: s, headers: { 'content-type': 'application/json' } });
}
function normalizeData(d) {
  const o = {};
  if (d && typeof d === 'object') for (const k in d) o[k] = String(d[k]);
  return o;
}

async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = { iss: env.FCM_CLIENT_EMAIL, scope: SCOPE, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600, sub: env.FCM_CLIENT_EMAIL };
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
