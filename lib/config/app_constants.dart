// DyKal App Constants
class AppConstants {
  static const appName = "DyKal";
  
  // Cloudinary - GRATIS TANPA CC, daftar 1 menit jadi
  // Daftar di cloudinary.com -> Settings -> Upload -> Upload presets -> Create unsigned preset
  static const cloudinaryCloudName = "hbhjusso";
  static const cloudinaryUploadPreset = "dykal_unsigned"; // unsigned preset name
  
  // ============================================================
  // TURN (relay untuk NAT ketat) - GRATIS, tinggal daftar
  // ============================================================
  // STUN gratis sudah cukup untuk mayoritas NAT. TURN dibutuhkan saat NAT
  // sangat ketat (symmetric NAT / jaringan kantor) supaya panggilan tidak gagal.
  // Pilih salah satu provider gratis di bawah, isi 3 kolom, lalu aplikasi
  // otomatis memakai TURN itu (di samping STUN & fallback OpenRelay).
  //
  // [1] CLOUDFLARE TURN - 1 TB/bulan GRATIS tanpa CC (paling dianjurkan)
  //     Daftar: https://dash.cloudflare.com (gratis) -> Realtime -> TURN
  //     -> buat TURN Key -> Generate static credentials di dashboard.
  //     TURN server: turn.cloudflare.com:3478 (udp) / turns:5349 (tcp)
  //
  // [2] EXPRESSTURN - 100 GB/bulan GRATIS
  //     Daftar: https://www.expressturn.com -> dashboard dapat username & password.
  //     STUN (tanpa login): stun:stun.expressturn.com:3478
  //     TURN: turn:free.expressturn.com:3478?transport=udp
  //     (ganti kolom turnUrl/turnUsername/turnCredential di bawah)
  //
  // [3] METERED TURN - 500 MB/bulan GRATIS tanpa CC (+ REST API)
  //     Daftar: https://www.metered.ca -> STUN/TURN -> Credentials.
  //     TURN server: turn.metered.ca:80 (udp) / turn.metered.ca:443 (tcp)
  //
  // Catatan jujur: kredensial statis di dalam APK bisa diekstrak dan kuotanya
  // dipakai pihak lain. Untuk aplikasi pribadi 2 orang ini tidak masalah;
  // untuk lebih aman bisa dipakai kredensial berumur pendek via REST API
  // (bisa ditambahkan nanti).
  static const String turnUrl = '';          // mis: 'turn:free.expressturn.com:3478?transport=udp'
  static const String turnUsername = '';     // username dari provider
  static const String turnCredential = '';   // password dari provider

  static List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[
      // ===== STUN gratis unlimited (cukup buat banyak kasus NAT) =====
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "stun:stun1.l.google.com:19302"},
      {"urls": "stun:stun2.l.google.com:19302"},
      {"urls": "stun:stun3.l.google.com:19302"},
      {"urls": "stun:stun4.l.google.com:19302"},
      {"urls": "stun:stun.cloudflare.com:3478"},
      {"urls": "stun:stun.expressturn.com:3478"},
      {"urls": "stun:stun.stunprotocol.org:3478"},
      {"urls": "stun:stun.nextcloud.com:443"},
      {"urls": "stun:stun.telnyx.com:3478"},
    ];

    // TURN hanya dipakai kalau kredensial sudah diisi (bukan placeholder)
    final hasTurn = turnUrl.isNotEmpty && turnUsername.isNotEmpty && turnCredential.isNotEmpty;
    if (hasTurn) {
      servers.add({
        "urls": turnUrl,
        "username": turnUsername,
        "credential": turnCredential,
      });
    }

    // Fallback OpenRelay (gratis, kadang tidak andal; WebRTC otomatis skip
    // server yang mati). Dibiarkan agar tetap ada relay cadangan.
    servers.addAll([
      {
        "urls": "turn:openrelay.metered.ca:80",
        "username": "openrelayproject",
        "credential": "openrelayproject",
      },
      {
        "urls": "turn:openrelay.metered.ca:443",
        "username": "openrelayproject",
        "credential": "openrelayproject",
      },
      {
        "urls": "turn:openrelay.metered.ca:443?transport=tcp",
        "username": "openrelayproject",
        "credential": "openrelayproject",
      },
    ]);

    return servers;
  }

  // DPI & Refresh Rate - Flutter auto handle, tapi kita paksa high refresh mode
  // Pakai flutter_displaymode untuk unlock 90/120Hz di Android
}
