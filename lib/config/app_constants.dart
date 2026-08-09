// DyKal App Constants
class AppConstants {
  static const appName = "DyKal";
  static const coupleId = "dykal_couple_01"; // Nanti dari invite code
  
  // Cloudinary - GRATIS TANPA CC, daftar 1 menit jadi
  // Daftar di cloudinary.com -> Settings -> Upload -> Upload presets -> Create unsigned preset
  static const cloudinaryCloudName = "hbhjusso";
  static const cloudinaryUploadPreset = "dykal_unsigned"; // unsigned preset name
  
  // TURN/STUN Gratis No CC
  static const iceServers = [
    // ===== STUN gratis unlimited (cukup buat banyak kasus NAT) =====
    {"urls": "stun:stun.l.google.com:19302"},
    {"urls": "stun:stun1.l.google.com:19302"},
    {"urls": "stun:stun2.l.google.com:19302"},
    {"urls": "stun:stun3.l.google.com:19302"},
    {"urls": "stun:stun4.l.google.com:19302"},
    {"urls": "stun:stun.cloudflare.com:3478"},
    {"urls": "stun:stun.stunprotocol.org:3478"},
    {"urls": "stun:stun.nextcloud.com:443"},
    {"urls": "stun:stun.telnyx.com:3478"},
    // ===== TURN (relay buat NAT strict). JUJUR (aturan #10/#11): =====
    // OpenRelay metered dulu gratis no-CC tapi SUDAH DEPRECATED. Disimpan sebagai
    // fallback (WebRTC otomatis skip server mati). TURN andal butuh akun
    // (Metered/Twilio/Cloudflare Calls) - bisa ditambah nanti kalau calls sering gagal.
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
  ];

  // DPI & Refresh Rate - Flutter auto handle, tapi kita paksa high refresh mode
  // Pakai flutter_displaymode untuk unlock 90/120Hz di Android
}
