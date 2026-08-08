import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class StoryViewer extends StatefulWidget {
  final String coupleId;
  const StoryViewer({super.key, required this.coupleId});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  final _audioPlayer = AudioPlayer();
  List<String> _photoUrls = [];
  List<String> _audioPaths = [];
  int _currentIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load audio playlist from SharedPreferences (global, permanent)
    final prefs = await SharedPreferences.getInstance();
    _audioPaths = prefs.getStringList('story_audio_playlist') ?? [];

    // Load photos from all albums
    final albumsSnap = await FirebaseFirestore.instance
        .collection('couples/${widget.coupleId}/albums')
        .get();
    for (final album in albumsSnap.docs) {
      final photosSnap = await FirebaseFirestore.instance
          .collection('couples/${widget.coupleId}/albums/${album.id}/photos')
          .limit(5)
          .get();
      for (final p in photosSnap.docs) {
        final url = (p.data() as Map<String, dynamic>)['url'] as String?;
        if (url != null) _photoUrls.add(url);
      }
    }

    if (_photoUrls.isEmpty) {
      if (mounted) { setState(() => _loading = false); }
      return;
    }

    // Shuffle photos for variety
    _photoUrls.shuffle();

    // Play random audio
    if (_audioPaths.isNotEmpty) {
      final randomPath = (_audioPaths..shuffle()).first;
      try {
        await _audioPlayer.setFilePath(randomPath);
        await _audioPlayer.setLoopMode(LoopMode.all);
        await _audioPlayer.play();
      } catch (_) {}
    }

    // Auto-advance photos every 4 seconds
    _startAutoAdvance();

    if (mounted) setState(() => _loading = false);
  }

  Timer? _timer;
  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_currentIndex < _photoUrls.length - 1) {
        setState(() => _currentIndex++);
      } else {
        Navigator.pop(context); // selesai
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: DyKalTheme.primary)));
    }
    if (_photoUrls.isEmpty) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Belum ada foto untuk story', style: TextStyle(color: Colors.white54))));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_currentIndex < _photoUrls.length - 1) {
            setState(() => _currentIndex++);
            _startAutoAdvance();
          } else {
            Navigator.pop(context);
          }
        },
        onLongPress: () => Navigator.pop(context),
        child: Stack(children: [
          // Full screen photo
          Positioned.fill(child: InteractiveViewer(
            child: Center(child: CachedNetworkImage(imageUrl: _photoUrls[_currentIndex], fit: BoxFit.contain)),
          )),
          // Progress bars (seperti IG story)
          Positioned(top: MediaQuery.of(context).padding.top + 8, left: 8, right: 8,
            child: Row(children: List.generate(_photoUrls.length, (i) =>
              Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: i <= _currentIndex ? DyKalTheme.primary : Colors.white24, borderRadius: BorderRadius.circular(2))))),
            ),
          ),
          // Close + audio indicator
          Positioned(top: MediaQuery.of(context).padding.top + 20, right: 8,
            child: Row(children: [
              if (_audioPaths.isNotEmpty)
                const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.music_note, color: Colors.white54, size: 16)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          // Counter
          Positioned(bottom: 40, left: 0, right: 0,
            child: Center(child: Text('${_currentIndex + 1} / ${_photoUrls.length}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ),
        ]),
      ),
    );
  }
}
