import 'package:just_audio/just_audio.dart';

/// Putar ringtone "tuuut" berulang saat panggilan masuk / sedang memanggil.
class RingtonePlayer {
  static final _p = AudioPlayer();
  static bool _on = false;

  static Future<void> start() async {
    if (_on) return;
    _on = true;
    try {
      await _p.setReleaseMode(ReleaseMode.loop);
      await _p.setVolume(0.9);
      await _p.setAsset('assets/sounds/ringtone.wav');
      await _p.play();
    } catch (_) {}
  }

  static Future<void> stop() async {
    _on = false;
    try { await _p.stop(); } catch (_) {}
  }
}
