import 'package:just_audio/just_audio.dart';
import 'ringtone_service.dart';

/// Putar ringtone "tuuut" berulang saat panggilan masuk / sedang memanggil.
class RingtonePlayer {
  static bool _on = false;

  static Future<void> start() async {
    if (_on) return;
    _on = true;
    try {
      await RingtoneService.playDefaultRingtone();
      await RingtoneService.vibrateCall();
    } catch (_) {}
  }

  static Future<void> stop() async {
    _on = false;
    try {
      await RingtoneService.stop();
    } catch (_) {}
  }

  // ============ Nada sambung panggilan KELUAR (Batch H) ============
  // ringback.wav: "tuuuut" 425 Hz, 1 dtk nyala + 4 dtk diam (baku nada
  // sambung Indonesia/ITU) — di-loop sampai diangkat/ditolak.
  // busy.wav: nada sibuk 0.5-0.5 x3 (diputar sekali saat panggilan ditolak).
  static final _rb = AudioPlayer();
  static bool _rbOn = false;

  static Future<void> startRingback() async {
    if (_rbOn) return;
    _rbOn = true;
    try {
      await _rb.setLoopMode(LoopMode.one);
      await _rb.setVolume(0.9);
      await _rb.setAsset('assets/sounds/ringback.wav');
      await _rb.play();
    } catch (_) {}
  }

  static Future<void> stopRingback() async {
    _rbOn = false;
    try { await _rb.stop(); } catch (_) {}
  }

  static Future<void> playBusyOnce() async {
    try {
      _rbOn = false;
      await _rb.stop();
      await _rb.setLoopMode(LoopMode.off);
      await _rb.setAsset('assets/sounds/busy.wav');
      await _rb.play();
    } catch (_) {}
  }

  static final _s = AudioPlayer();
  static Future<void> playMsgSent() async {
    try {
      await _s.stop();
      await _s.setLoopMode(LoopMode.off);
      await _s.setVolume(0.7);
      await _s.setAsset('assets/sounds/msg_sent.wav');
      await _s.play();
    } catch (_) {}
  }

  static Future<void> playNotif() async {
    try {
      await RingtoneService.playDefaultNotification();
    } catch (_) {}
  }

  static Future<void> playCallEnded() async {
    try {
      await _s.stop();
      await _s.setLoopMode(LoopMode.off);
      await _s.setVolume(0.8);
      await _s.setAsset('assets/sounds/busy.wav');
      await _s.play();
    } catch (_) {}
  }
}
