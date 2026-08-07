import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/theme.dart';
import '../../services/call_service.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key});
  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  final call = DyKalCallService();
  double volume = 0.8;

  @override
  void initState() {
    super.initState();
    call.startAudioCall();
  }

  @override
  void dispose() {
    call.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1C1E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                IconButton(onPressed: ()=> Navigator.pop(context), icon: Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.regular), color: Colors.white)),
                Spacer(),
                Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(width: 8,height:8, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)), SizedBox(width: 6), Text("01:23", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])),
              ]),
            ),
            Spacer(),
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient, boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.4), blurRadius: 30)]),
              child: Center(child: Text("D", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Ayang", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(width: 8),
              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: DyKalTheme.primary, size: 20),
            ]),
            SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(PhosphorIcons.waveform(PhosphorIconsStyle.regular), color: Colors.white70, size: 14),
              SizedBox(width: 6),
              Text("Sedang terhubung • HD Voice", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
            SizedBox(height: 24),
            // Volume Slider - Icons rounded
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(PhosphorIcons.speakerHigh(PhosphorIconsStyle.regular), color: Colors.white, size: 20),
                Expanded(child: Slider(value: volume, min: 0, max: 1, activeColor: DyKalTheme.primary, inactiveColor: Colors.white24, onChanged: (v){ setState(()=> volume=v); call.setVolume(v); })),
                Icon(PhosphorIcons.speakerLow(PhosphorIconsStyle.regular), color: Colors.white70, size: 16),
              ]),
            ),
            Spacer(),
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _circleBtn(PhosphorIcons.microphoneSlash(PhosphorIconsStyle.regular), "Mute", call.isAudioMuted, () => setState(()=> call.toggleMute())),
                  _circleBtn(PhosphorIcons.speakerHigh(PhosphorIconsStyle.regular), "Speaker", call.isSpeakerOn, () => setState(()=> call.toggleSpeaker())),
                  _circleBtn(PhosphorIcons.videoCamera(PhosphorIconsStyle.regular), "Video", false, () async {
                    await call.switchToVideo();
                    if (mounted) Navigator.pushReplacementNamed(context, '/videoCall');
                  }),
                ]),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: ()=> Navigator.pop(context),
                  child: Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Icon(PhosphorIcons.phoneDisconnect(PhosphorIconsStyle.fill), color: Colors.white, size: 28)),
                ),
                SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.regular), size: 12, color: Colors.white60),
                  SizedBox(width: 4),
                  Text("Geser ke VideoCall kapan saja", style: TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, String label, bool active, VoidCallback onTap) {
    return Column(children: [
      GestureDetector(
        onTap: onTap,
        child: Container(width: 56, height: 56, decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 22)),
      ),
      SizedBox(height: 6),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}
