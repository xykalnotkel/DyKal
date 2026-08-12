# Audit Spek UI/Arsitektur DyKal v2 vs Kode Saat Ini

Dokumen rujukan: `Spesifikasi_Aplikasi_DyKal_v2.pdf` (6 halaman, dari owner).
Tanggal audit: 2026-08-12 — auditor: Arena Dev (XYSTUDIO).

> UPDATE 2026-08-12 (v1.3.0 / Batch G): seluruh gap di bawah SUDAH DIKERJAKAN.
> - Bagian 4 (FCM data-only): worker support `dataOnly` + tipe `call_cancel`;
>   app menandai `notifCap: v2` di users/{uid}; pengirim hanya minta data-only
>   bila device tujuan mendukung (app lama tetap hybrid — backward compatible).
>   Notif chat = MessagingStyle + avatar + aksi Balas (inline input), Tandai
>   Dibaca, Bisukan — bekerja foreground via onMessage DAN killed via
>   firebaseMessagingBackgroundHandler + dykalNotifBackgroundResponse.
> - Bagian 5A: notif panggilan memakai channel *_v2 dengan NADA DERING TELPON
>   SISTEM (UriAndroidNotificationSound) + fullScreenIntent + aksi Angkat/Tolak;
>   caller batal -> push call_cancel (ttl 10s) menghentikan dering pasangan
>   seketika + membersihkan notif tray 7777.
> - Bagian 5B: ReturnToCallBar hijau berkedip di MainNav; sesi panggilan kini
>   singleton-statis (DyKalCallService.current) sehingga layar bisa dikecilkan
>   (chevron) dan di-reJOIN tanpa memutus panggilan.

---

## 1. Perbaikan Bug UI Input Chat (border kotak kaku)

**Status: SUDAH TERPENUHI**

Spek minta: `InputBorder.none` di semua state + `filled: true` + `fillColor: Colors.transparent` + container kapsul radius 24.

Kode kita (`chat_screen.dart` ~L985): TextField sudah dibungkus container rounded dan memakai `border: InputBorder.none`. Catatan teknis: di Flutter, `enabledBorder/focusedBorder/errorBorder` **otomatis fallback ke `border`** bila tidak di-set eksplisit — jadi menulis 5 state seperti spek itu redundan (hasil visual identik). Tidak ada blok kotak tumpuk di build terakhir.

Tindakan: tidak perlu. (Opsional: tambah `contentPadding` eksplisit biar identik plek WA — kosmetik, bukan bug.)

## 2. Ukuran Bubble Chat Ideal

**Status: SUDAH (bahkan melampaui spek)**

| Properti | Spek v2 | Kode kita | Status |
|---|---|---|---|
| Max width | 70–75% layar | `0.72` lebar layar | OK, di dalam rentang |
| Padding dalam | 12h / 8v | 12h / 6v (teks), 3 (gambar) | OK (selisih 2dp, bubble lebih ramping) |
| Radius | 16, sudut ekor 4 | `BubbleStyle.instance.radius(isMe)` — ADA pilihan Bulat/Kotak/Ekor per user | Melampaui spek: ekor 4dp ada di gaya "Ekor", user bisa pilih |
| Margin antar pesan | 2 / 2 | `EdgeInsets.symmetric(vertical: 2)` | OK |
| Waktu+status di dalam bubble (Wrap ala WA) | wajib | Ada + toggle `bubble_meta_inside` (batch F: dalam ala WA / luar ala iOS) | Melampaui spek |

Tindakan: tidak perlu.

## 3. Voice Note Gesture (Lock / Cancel / Tap Send)

**Status: SUDAH TERPENUHI**

- Swipe up `dy < -60` lock — ada persis (plus haptic `mediumImpact` saat masuk zona kunci).
- Swipe left cancel — kita `-70` (spek `-80`): beda 10px, lebih sensitif sedikit, masih wajar.
- Lepas jari tanpa lock -> langsung kirim (`_stopRec(send: true)`); cancel -> hapus file temp + SnackBar konfirmasi.
- Sudah diperkuat batch F: waveform nyata per 200ms + durasi riil di player.

Tindakan: tidak perlu.

## 4. Arsitektur FCM: Data-Only Message

**Status: SUDAH DIIMPLEMENTASIKAN (v1.3.0 / Batch G)** — gap di bawah tinggal sebagai catatan desain pra-implem.

| Sub-item | Spek v2 | Kode kita | Gap |
|---|---|---|---|
| Payload | data-only, TANPA key `notification` | Worker kirim hybrid (`notification` + `data`) | Ya |
| Field chat | type, chat_id, sender_id, sender_name, sender_avatar, message_body, timestamp | Hanya coupleId/type/callerName/callType | Ya — avatar & sender_name tidak pernah dikirim |
| Field call | call_id, call_type, caller_name, caller_avatar, channel_id, ttl 30s | callerName/callType saja; ttl 45s di worker | Sebagian |
| Efek rendered | MessagingStyle avatar + aksi Balas/Selesai di SEMUA state | Background/killed -> tray auto-render polos (tanpa avatar/aksi), foreground -> custom | Ya |

Kenapa gap ini terjadi (kenapa -> akibat): selama worker menyertakan key `notification`, Android mengambil alih rendering saat app killed/background — handler Dart kita tidak pernah dipanggil, jadi avatar bundar + tombol Balas tidak akan pernah muncul di state paling penting (app mati).

Rencana Batch G:
1. Worker: untuk `type=chat/call`, kirim **data-only** (hapus key `notification`); pertahankan `android.priority=HIGH`.
2. `push_service.dart`: sertakan `senderName`, `senderAvatar`, `messageBody` (truncated), `timestamp`, `msgType` ke map `data`.
3. App: daftarkan `@pragma('vm:entry-point')` background isolate -> render lewat `flutter_local_notifications` MessagingStyle + download avatar + aksi Balas (inline reply) / Selesai.
4. Risiko & mitigasi: data-only bisa ditelan OEM battery killer agresif -> mitigasi: tetap sertakan `android.notification` ringan (channel+icon) TANPA key notification level atas... realitanya FCM mengharuskan key notification untuk auto-render; jadi keputusan: full data-only + high priority, dipantau 2 device. iOS apns tetap butuh `aps.alert` — sementara Android-only dulu.
5. ttl call: 45s (kita) vs 30s (spek) — biarkan 45s, lebih memaafkan jaringan lambat.

## 5. Penanganan Panggilan

**Status: SUDAH DIIMPLEMENTASIKAN (v1.3.0 / Batch G)** — gap di bawah tinggal catatan desain pra-implem.

| Sub-item | Spek v2 | Kode kita | Gap |
|---|---|---|---|
| Fullscreen native call saat HP terkunci | flutter_callkit_incoming + system ringtone | Incoming screen sendiri + notif channel dykal_call_audio/video | Sebagian — belum ada full-screen intent saat locked |
| CANCEL_CALL dari caller -> stop dering | wajib | BELUM ADA: worker whitelist tidak mengenal tipe cancel; caller batalkan -> HP pasangan tetap bunyi sampai ttl habis | YA — bug nyata UX |
| Topbar hijau pulse "Ketuk untuk kembali ke panggilan" | wajib | BELUM ADA (tidak ada kode return-to-call bar sama sekali) | Ya |
| Call history detail | ada (batch F) | — | OK |

Rencana Batch G:
1. Tambah tipe `call_cancel` di whitelist worker (push key-guarded, dari caller saat `_cleanup` sebelum connect).
2. App: terima `call_cancel` -> cancel notif id call + stop ringtone + tutup incoming screen bila terbuka.
3. Full-screen intent: notif panggilan pakai `fullScreenIntent: true` (flutter_local_notifications mendukung) + system ringtone URI channel panggilan. (flutter_callkit_incoming opsional — lib kita sendiri sudah dekat paritas; menambah dep native berat hanya untuk paritas visual bisa ditunda).
4. Return-to-call bar: `CallService.isInCall` global + overlay strip hijau pulse di MainNav (tap -> buka CallScreen aktif sesuai callType).

---

## Ringkasan Eksekutif

- Terpenuhi penuh: #1 input, #2 bubble, #3 VN gesture.
- Gap nyata Batch G: **FCM data-only + avatar/aksi**, **call_cancel**, **Return-to-call bar**, (opsional) full-screen intent call.
- Prinsip: semua perubahan worker tetap backward-compatible (app lama v<=1.1.9 masih menerima notif hybrid? TIDAK — app lama bergantung key notification untuk background; bila worker berhenti mengirim `notification`, app lama killed tidak dapat notif. Mitigasi: versi-gate via field `appVer` yang dikirim app saat register token? Atau terima risiko: rilis v1.2.0 serentak lalu worker data-only setelah mayoritas device upgrade. Rekomendasi: worker kirim data-only HANYA jika request menyertakan `dataOnly: true` dari app v1.2.0+.)
