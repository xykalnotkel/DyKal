import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import '../../config/theme.dart';
import '../../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final call = DyKalCallService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  String filter = 'none';

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    final stream = await call.startVideoCall();
    _localRenderer.srcObject = stream;
    setState(() {});
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    call.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // REMOTE VIDEO FULLSCREEN dengan Filter
          Positioned.fill(
            child: call.getFilterColor() != null
                ? ColorFiltered(colorFilter: call.getFilterColor()!, child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: false))
                : RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: false),
          ),
          // Jika remote belum ada, pakai local sebagai preview gede
          if (_remoteRenderer.srcObject == null)
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: call.getFilterColor() ?? ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          // Gradient top
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 120, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent])))),
          
          // TOP BAR
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.videocam, color: Colors.white, size: 14), SizedBox(width: 6), Text("DyKal Video • 01:24", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))])),
                Spacer(),
                IconButton(onPressed: () => call.switchCamera(), icon: Icon(Icons.sync(), color: Colors.white)),
                IconButton(onPressed: () => call.startScreenShare(), icon: Icon(call.isScreenSharing ? Icons.desktop_windows() : Icons.share(), color: call.isScreenSharing ? DyKalTheme.primary : Colors.white)),
              ]),
            ),
          ),

          // LOCAL PIP (Picture in Picture) - Bisa drag
          Positioned(
            top: 100, right: 16,
            child: GestureDetector(
              onPanUpdate: (d){},
              child: Container(
                width: 110, height: 160,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24, width: 2), boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)]),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  if (!call.isVideoEnabled) Container(color: Colors.black87, child: Center(child: Icon(Icons.videocam_off(), color: Colors.white))),
                ]),
              ),
            ),
          ),

          // FILTER BAR (Efek kayak IG)
          Positioned(
            left: 16, right: 16, bottom: 140,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip("none", "Normal", Icons.auto_awesome()),
                _filterChip("warm", "Warm", Icons.wb_sunny()),
                _filterChip("cool", "Cool", Icons.ac_unit()),
                _filterChip("bw", "B&W", Icons.dark_mode()),
                _filterChip("beauty", "Beauty", Icons.auto_fix_high()),
              ]),
            ),
          ),

          // BOTTOM CONTROLS
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _controlBtn(Icons.mic_off(), call.isAudioMuted, () => setState(()=> call.toggleMute())),
                _controlBtn(Icons.videocam_off(), !call.isVideoEnabled, () => setState(()=> call.toggleCamera())),
                GestureDetector(onTap: ()=> Navigator.pop(context), child: Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Icon(Icons.call_end, color: Colors.white, size: 26))),
                _controlBtn(Icons.volume_up(), call.isSpeakerOn, () => setState(()=> call.toggleSpeaker())),
                _controlBtn(Icons.desktop_windows(), call.isScreenSharing, () => setState(()=> call.isScreenSharing ? call.stopScreenShare() : call.startScreenShare())),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    final active = filter == id;
    return GestureDetector(
      onTap: () => setState((){ filter = id; call.setFilter(id); }),
      child: Container(
        margin: EdgeInsets.only(right: 10),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? DyKalTheme.primary : Colors.white24)),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _controlBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 48, height: 48, decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
    );
  }
}
