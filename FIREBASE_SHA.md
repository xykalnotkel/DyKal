# Firebase SHA untuk DyKal

Keystore: `android/app/dykal-release-key.jks`
Alias: `dykal`
Store Password: `DyKal2026!`
Key Password: `DyKal2026!`
Valid until: 2053-12-23

## SHA untuk Firebase Console

Buka Firebase Console → Project Settings → Your apps → Android app `com.dykal.app` → Add fingerprint

```
SHA-1:   72:31:52:2E:5F:65:24:DA:63:F5:6D:8E:D8:C1:2A:E7:5B:C6:67:6D
SHA-256: 74:D8:37:04:BE:30:F7:6A:B3:0B:57:0B:F6:22:15:C9:0B:92:C8:E6:A6:E7:B3:E0:8C:F5:DB:77:AB:FC:31:8C
```

### Cara dapat SHA manual (jika perlu)
```bash
keytool -list -v -keystore android/app/dykal-release-key.jks -alias dykal -storepass DyKal2026!
```

### Debug SHA (otomatis debug keystore, biasanya tidak perlu)
Jika butuh SHA debug untuk testing:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

### Catatan
- SHA ini sudah terpasang di keystore yang ter-commit di repo untuk build GitHub Actions
- Jika kamu generate ulang keystore, SHA akan berubah dan harus update di Firebase Console lagi
- Untuk update, hapus fingerprint lama dan tambah yang baru di Firebase Console
