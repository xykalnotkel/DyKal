# Firebase SHA untuk DyKal

Keystore rilis: **tidak disimpan di repositori**.
Keystore (`dykal-release-key.jks`), password, dan alias disimpan **hanya** di GitHub Secrets:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.

> Penting: Password keystore JANGAN pernah ditulis di file yang di-commit ke git.
> Jika keystore beserta passwordnya pernah terekspos (commit, salinan tidak aman),
> regenerasi keystore baru adalah tindakan wajib.

## SHA untuk Firebase Console

Buka Firebase Console -> Project Settings -> Your apps -> Android app `com.dykal.app` -> Add fingerprint

```
SHA-1:   72:31:52:2E:5F:65:24:DA:63:F5:6D:8E:D8:C1:2A:E7:5B:C6:67:6D
SHA-256: 74:D8:37:04:BE:30:F7:6A:B3:0B:57:0B:F6:22:15:C9:0B:92:C8:E6:A6:E7:B3:E0:8C:F5:DB:77:AB:FC:31:8C
```

### Cara mendapatkan SHA (jika perlu)

Jalankan pada mesin yang memiliki keystore (password diambil dari GitHub Secrets, bukan dari file):

```bash
keytool -list -v -keystore dykal-release-key.jks -alias <KEY_ALIAS> -storepass <KEYSTORE_PASSWORD>
```

### Debug SHA (untuk testing)

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

### Catatan

- Fingerprint harus sesuai dengan keystore yang di-set di secret `KEYSTORE_BASE64`.
- Jika keystore digenerate ulang, SHA berubah dan wajib diperbarui di Firebase Console,
  serta secret `KEYSTORE_BASE64` dan `KEY_ALIAS` harus diganti dengan yang baru.
