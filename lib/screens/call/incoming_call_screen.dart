import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String _type = 'video';
  String _callerName = 'Ayang';
  StreamSubscription? _sub;
  final call = DyKalCallService();
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    final coupleId = AuthService().coupleId ?? '';
    _type = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'video';
    // Ambil nama caller + awasi kalau dibatalkan
    _sub = FirebaseFirestore.instance.doc('calls/$coupleId').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null || data['status'] == 'ended') {
        if (!_gone) { _gone = true; Navigator.pop(context); }
        return;
      }
      setState(() {
        _type = (data['type'] as String?) ?? 'video';
        _callerName = (data['callerName'] as String?) ?? 'Ayang';
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _accept() {
    if (_gone) return;
    _gone = true;
    _sub?.cancel();
    final route = _type == 'video' ? '/videoCall' : '/audioCall';
    Navigator.of(context).pushReplacementNamed(route, arguments: {'isCaller': false, 'type': _type});
  }

  void _decline() async {
    if (_gone) return;
    _gone = true;
    await call.declineIncoming();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      body: SafeArea(child: Column(children: [
        const Spacer(),
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: DyKalTheme.dykalGradient, boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.4), blurRadius: 30)]),
          child: Center(child: Text(_callerName.isNotEmpty ? _callerName[0] : '?', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(height: 18),
        Text(_callerName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_type == 'video' ? Icons.videocam : Icons.call, color: DyKalTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(_type == 'video' ? 'Panggilan Video Masuk' : 'Panggilan Suara Masuk', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [
            GestureDetector(
              onTap: _decline,
              child: Container(width: 68, height: 68, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 28)),
            ),
            const SizedBox(height: 8),
            const Text('Tolak', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          Column(children: [
            GestureDetector(
              onTap: _accept,
              child: Container(width: 68, height: 68, decoration: const BoxDecoration(color: DyKalTheme.online, shape: BoxShape.circle),
                child: const Icon(Icons.call, color: Colors.white, size: 28)),
            ),
            const SizedBox(height: 8),
            const Text('Terima', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 40),
      ])),
    );
  }
}
