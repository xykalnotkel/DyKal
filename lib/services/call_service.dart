import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'auth_service.dart';
import 'push_service.dart';

/// Service WebRTC dengan signaling via Firestore (top-level doc calls/{coupleId}).
/// - Caller: startOutgoing -> offer + status 'ringing'
/// - Callee: acceptIncoming -> answer + status 'answered'
/// - ICE ditukar via subkoleksi offerCandidates / answerCandidates
class DyKalCallService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  String callType = 'video'; // 'audio' | 'video'
  bool muted = false;
  bool videoOn = true;
  bool speakerOn = true;
  bool screenSharing = false;
  String? lastError; // FIX: pesan error screen-share dll, biar UI bisa tampilkan (bukan silent crash)
  bool connected = false;
  String peerFilter = 'none';

  StreamSubscription? _ansSub;       // answerCandidates (dipakai caller)
  StreamSubscription? _offerCandSub; // offerCandidates (dipakai callee)
  StreamSubscription? _docSub;       // dokumen call (answer / status)
  bool _remoteDescriptionSet = false;

  String get coupleId => AuthService().coupleId ?? '';
  String get myId => AuthService().myId;
  String get partnerId => AuthService().partnerId ?? '';

  // ---------- Inisialisasi koneksi ----------
  Future<void> _createPc() async {
    _pc = await createPeerConnection({
      'iceServers': AppConstants.iceServers,
      'sdpSemantics': 'unified-plan',
    });

    _pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        remoteStream = e.streams[0];
        notifyListeners();
      }
    };
    _pc!.onIceCandidate = (c) async {
      await _db.collection('calls/$coupleId/${_myCandCol()}').add(c.toMap());
    };
    _pc!.onConnectionState = (s) {
      connected = s == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      notifyListeners();
    };
  }

  String _myCandCol() {
    // caller menulis ke offerCandidates, callee ke answerCandidates
    return _amCaller ? 'offerCandidates' : 'answerCandidates';
  }

  String _peerCandCol() => _amCaller ? 'answerCandidates' : 'offerCandidates';

  bool get _amCaller => _callerFlag;
  bool _callerFlag = true;

  Future<void> _addLocalTracks() async {
    if (localStream == null) return;
    for (final t in localStream!.getTracks()) {
      await _pc!.addTrack(t, localStream!);
    }
  }

  // ---------- Media lokal ----------
  Future<void> _openMedia(bool video) async {
    callType = video ? 'video' : 'audio';
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}, 'frameRate': {'ideal': 24}}
          : false,
    });
    localStream = stream;
    notifyListeners();
  }

  // ---------- CALLER ----------
  Future<void> startOutgoing(String type) async {
    _callerFlag = true;
    await _openMedia(type == 'video');
    await _createPc();
    await _addLocalTracks();

    final offer = await _pc!.createOffer({});
    await _pc!.setLocalDescription(offer);

    await _db.doc('calls/$coupleId').set({
      'callerId': myId,
      'callerName': AuthService().myName,
      'type': callType,
      'status': 'ringing',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Push notif "panggilan masuk" ke pasangan (jalan walau app-nya di-kill)
    PushService.notifyPartner(
      title: '📞 Panggilan ${callType == 'video' ? 'Video' : 'Suara'} Masuk',
      body: '${AuthService().myName} menelpon kamu',
      type: 'call',
      callerName: AuthService().myName,
      callType: callType,
    );

    // Dengar jawaban & ICE lawan
    _docSub = _db.doc('calls/$coupleId').snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;
      if (data['status'] == 'ended') { await _cleanup(); return; }
      final pf = data['calleeFilter'] as String?;
      if (pf != null && pf != peerFilter) { peerFilter = pf; notifyListeners(); }
      final answer = data['answer'];
      if (answer != null && !_remoteDescriptionSet) {
        _remoteDescriptionSet = true;
        await _pc?.setRemoteDescription(RTCSessionDescription(answer['sdp'] as String, answer['type'] as String));
      }
    });
    _ansSub = _db.collection('calls/$coupleId/answerCandidates').snapshots().listen((qs) async {
      for (final d in qs.docChanges) {
        if (d.type == DocumentChangeType.added) {
          final _m = d.doc.data() as Map<String,dynamic>; await _pc?.addCandidate(RTCIceCandidate(_m["candidate"] as String?, _m["sdpMid"] as String?, _m["sdpMLineIndex"] as int?));
        }
      }
    });
  }

  // ---------- CALLEE ----------
  Future<void> acceptIncoming() async {
    _callerFlag = false;
    final docSnap = await _db.doc('calls/$coupleId').get();
    final data = docSnap.data() as Map<String, dynamic>?;
    if (data == null) throw Exception('Panggilan sudah berakhir');
    callType = (data['type'] as String?) ?? 'video';

    await _openMedia(callType == 'video');
    await _createPc();
    await _addLocalTracks();

    // Terapkan offer dari lawan
    final offer = data['offer'] as Map<String, dynamic>?;
    await _pc!.setRemoteDescription(RTCSessionDescription(offer!['sdp'] as String, offer!['type'] as String));

    final answer = await _pc!.createAnswer({});
    await _pc!.setLocalDescription(answer);
    await _db.doc('calls/$coupleId').update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'status': 'answered',
    });

    // Terima ICE lawan (offerCandidates)
    _offerCandSub = _db.collection('calls/$coupleId/offerCandidates').snapshots().listen((qs) async {
      for (final d in qs.docChanges) {
        if (d.type == DocumentChangeType.added) {
          final _m = d.doc.data() as Map<String,dynamic>; await _pc?.addCandidate(RTCIceCandidate(_m["candidate"] as String?, _m["sdpMid"] as String?, _m["sdpMLineIndex"] as int?));
        }
      }
    });
    _docSub = _db.doc('calls/$coupleId').snapshots().listen((doc) async {
      final d = doc.data();
      if (d == null || d['status'] == 'ended') { await _cleanup(); return; }
      final pf = d['callerFilter'] as String?;
      if (pf != null && pf != peerFilter) { peerFilter = pf; notifyListeners(); }
    });
  }

  // ---------- Kontrol ----------
  void toggleMute() {
    muted = !muted;
    for (final t in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleVideo() {
    videoOn = !videoOn;
    for (final t in localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = videoOn;
    }
    notifyListeners();
  }

  /// Tulis filter pilihanku ke call doc -> lawan lihat aku ter-filter (filter di-display sisi penerima)
  Future<void> setMyFilter(String f) async {
    final field = _amCaller ? 'callerFilter' : 'calleeFilter';
    try {
      await _db.doc('calls/$coupleId').update({field: f});
    } catch (_) {}
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    try { await Helper.setSpeakerphoneOn(speakerOn); } catch (_) {}
    notifyListeners();
  }

  Future<bool> toggleScreenShare() async {
    if (_pc == null) { lastError = 'Koneksi panggilan belum siap'; notifyListeners(); return false; }
    try {
      final senders = await _pc!.getSenders();
      final vSenders = senders.where((s) => s.track?.kind == 'video').toList();
      if (vSenders.isEmpty) { lastError = 'Tidak ada track video untuk dibagikan'; notifyListeners(); return false; }
      if (!screenSharing) {
        final screen = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
        final screenTrack = screen.getVideoTracks().first;
        await vSenders.first.replaceTrack(screenTrack);
        screenSharing = true;
        screenTrack.onEnded = () => toggleScreenShare();
      } else {
        final cam = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': false});
        final camTrack = cam.getVideoTracks().first;
        await vSenders.first.replaceTrack(camTrack);
        screenSharing = false;
      }
      lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Screen share gagal: $e';
      screenSharing = false;
      notifyListeners();
      return false;
    }
  }

  // ---------- Akhir panggilan ----------
  Future<void> hangUp() async {
    try {
      await _db.doc('calls/$coupleId').update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
    await _cleanup();
  }

  Future<void> declineIncoming() async {
    try {
      await _db.doc('calls/$coupleId').update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _ansSub?.cancel();
    await _offerCandSub?.cancel();
    await _docSub?.cancel();
    _ansSub = _offerCandSub = _docSub = null;
    for (final t in [...?localStream?.getTracks(), ...?remoteStream?.getTracks()]) {
      try { await t.stop(); } catch (_) {}
    }
    localStream?.dispose();
    remoteStream?.dispose();
    await _pc?.close();
    _pc = null;
    localStream = remoteStream = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
