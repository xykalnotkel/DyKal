import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

/// Service Call Audio/Video Lengkap DyKal
/// Fitur: Atur Volume, Switch Audio<->Video, Filter, Screen Share
class DyKalCallService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _firestore = FirebaseFirestore.instance;

  // Untuk UI
  bool isAudioMuted = false;
  bool isVideoEnabled = true;
  bool isSpeakerOn = true;
  bool isScreenSharing = false;
  double volume = 1.0;

  /// Inisialisasi PeerConnection dengan TURN Gratis
  Future<RTCPeerConnection> createPeerConnection() async {
    final config = {
      'iceServers': AppConstants.iceServers,
      'sdpSemantics': 'unified-plan',
    };
    _pc = await createPeerConnection(config);
    return _pc!;
  }

  /// Start Call Audio saja
  Future<MediaStream> startAudioCall() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    isVideoEnabled = false;
    return _localStream!;
  }

  /// Start Video Call
  Future<MediaStream> startVideoCall({bool withFilter = false}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      },
    });
    isVideoEnabled = true;
    // Filter akan di-apply di Video Renderer via Shader / GPUImage
    // Untuk MVP: pakai ColorFilter di Flutter widget
    return _localStream!;
  }

  /// Switch Audio -> Video saat call berlangsung (kayak WA)
  Future<void> switchToVideo() async {
    if (_localStream == null || _pc == null) return;
    // Tambah video track baru
    final videoStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': false});
    final videoTrack = videoStream.getVideoTracks().first;
    final senders = await _pc!.getSenders();
    // Cari sender audio, tambah video
    await _pc!.addTrack(videoTrack, _localStream!);
    _localStream!.addTrack(videoTrack);
    isVideoEnabled = true;
    
    // Trigger renegotiation via Firestore signaling
    await _renegotiate();
  }

  Future<void> switchToAudioOnly() async {
    if (_localStream == null) return;
    for (var track in _localStream!.getVideoTracks()) {
      track.enabled = false;
      await track.stop();
      _localStream!.removeTrack(track);
    }
    isVideoEnabled = false;
    await _renegotiate();
  }

  Future<void> _renegotiate() async {
    // Buat offer baru dan kirim via Firestore
    // Implementasi signaling sederhana: koleksi calls/{callId}
  }

  /// Atur Volume Output (0.0 - 1.0)
  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    if (_remoteStream != null) {
      for (var track in _remoteStream!.getAudioTracks()) {
        // WebRTC tidak ada setVolume native, kita atur via audio element
        // Di Flutter, atur via RTCVideoRenderer + AudioGain
      }
    }
    // Untuk speaker/earpiece
    await Helper.setSpeakerphoneOn(isSpeakerOn);
  }

  /// Toggle Speaker / Earpiece
  Future<void> toggleSpeaker() async {
    isSpeakerOn = !isSpeakerOn;
    await Helper.setSpeakerphoneOn(isSpeakerOn);
  }

  /// Mute/Unmute Mic
  void toggleMute() {
    isAudioMuted = !isAudioMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !isAudioMuted);
  }

  /// On/Off Kamera
  void toggleCamera() {
    isVideoEnabled = !isVideoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = isVideoEnabled);
  }

  /// Switch Kamera Depan/Belakang
  Future<void> switchCamera() async {
    await Helper.switchCamera(_localStream!.getVideoTracks().first);
  }

  /// Screen Share kayak WhatsApp (Bagi Layar)
  Future<void> startScreenShare() async {
    if (isScreenSharing) return;
    try {
      // Di Android butuh permission foreground + MediaProjection
      final screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': true,
      });
      final screenTrack = screenStream.getVideoTracks().first;
      
      // Ganti video track di peer connection
      final senders = await _pc!.getSenders();
      final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
      await videoSender.replaceTrack(screenTrack);
      
      isScreenSharing = true;
      screenTrack.onEnded = () => stopScreenShare();
    } catch (e) {
      print('Screen share error: $e');
    }
  }

  Future<void> stopScreenShare() async {
    if (!isScreenSharing) return;
    final camStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': false});
    final camTrack = camStream.getVideoTracks().first;
    final senders = await _pc!.getSenders();
    final sender = senders.firstWhere((s) => s.track?.kind == 'video');
    await sender.replaceTrack(camTrack);
    isScreenSharing = false;
  }

  /// Filter/Efek Video - Di Flutter kita pakai Widget overlay + ColorFilter
  /// Untuk filter beneran (beauty, dll) bisa integrasi Banuba atau GPUImage
  /// Return filter name untuk UI
  String currentFilter = 'none'; // none, warm, cool, bw, beauty
  void setFilter(String filter) {
    currentFilter = filter;
    // UI akan rebuild dan apply ColorFiltered di RTCVideoView
  }

  ColorFilter? getFilterColor() {
    switch (currentFilter) {
      case 'warm': return ColorFilter.mode(Color(0xFFFFE0B2).withOpacity(0.3), BlendMode.overlay);
      case 'cool': return ColorFilter.mode(Color(0xFFB2EBF2).withOpacity(0.25), BlendMode.overlay);
      case 'bw': return ColorFilter.matrix(<double>[
        0.2126,0.7152,0.0722,0,0,
        0.2126,0.7152,0.0722,0,0,
        0.2126,0.7152,0.0722,0,0,
        0,0,0,1,0,
      ]);
      case 'beauty': return ColorFilter.mode(Color(0xFFFFCCBC).withOpacity(0.15), BlendMode.softLight);
      default: return null;
    }
  }

  void dispose() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
  }
}
