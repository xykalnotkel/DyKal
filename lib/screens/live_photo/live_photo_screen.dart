import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../services/live_photo_tool.dart';
import '../../services/motion_photo_writer.dart';

/// BATCH J — Live Photo Fase 1 (spek: uploads/FITUR-LIVE-PHOTO.md, roadmap Fase 1).
/// Cakupan fase ini (persis roadmap): Import MP4 → trim slider (maks 30 dtk) →
/// cover → preset look → SIMPAN VIDEO + SHARE. Semua proses 100% on-device
/// (Media3 Transformer via LivePhotoTool.kt) = Rp 0, tanpa server transcode.
///
/// Jujur soal batas fase:
///  - Badge "LIVE" otomatis di galeri = Fase 2 (writer Motion Photo / byte JPG+MP4).
///  - Tombol "Kirim ke Pasangan" (E2EE + notif worker) = Fase 3 -> sengaja dimatikan.
class LivePhotoScreen extends StatefulWidget {
  const LivePhotoScreen({super.key});

  @override
  State<LivePhotoScreen> createState() => _LivePhotoScreenState();
}

class _LivePhotoScreenState extends State<LivePhotoScreen> {
  static const int _maxSpanMs = 30000; // soft cap spek: ~30 dtk

  String? _srcPath;
  VideoPlayerController? _c;
  RangeValues _win = const RangeValues(0, 0);
  double _coverMs = 0;
  double _durMs = 0;
  bool _scrubbing = false;

  LivePhotoPreset _preset = LivePhotoPreset.all.first;
  String? _coverPath;
  int _coverSeq = 0;
  Timer? _coverDebounce;

  bool _processing = false;
  double _prog = 0; // 0..1
  String? _outPath;
  int _outSize = 0;

  @override
  void dispose() {
    _coverDebounce?.cancel();
    _c?.removeListener(_enforceWindow);
    _c?.dispose();
    LivePhotoTool.cancel(); // jaga-jaga: batalkan job kalau layar ditutup
    super.dispose();
  }

  String _fmt(double ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickVideo() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      final c = VideoPlayerController.file(File(x.path));
      await c.initialize();
      await c.setLooping(true);
      final dur = c.value.duration.inMilliseconds.toDouble();
      final span = dur < 10000 ? dur : 10000.0; // default window 10 dtk
      _c?.removeListener(_enforceWindow);
      _c?.dispose();
      _c = c;
      c.addListener(_enforceWindow);
      await c.play();
      setState(() {
        _srcPath = x.path;
        _durMs = dur;
        _win = RangeValues(0, span);
        _coverMs = span / 2;
        _outPath = null;
        _coverPath = null;
      });
      _refreshCover();
    } catch (e) {
      _toast('Gagal membuka video: $e');
    }
  }

  void _enforceWindow() {
    final c = _c;
    if (c == null || !c.value.isInitialized || _scrubbing) return;
    final p = c.value.position.inMilliseconds;
    if (p >= _win.end - 40 || p < _win.start - 350) {
      c.seekTo(Duration(milliseconds: _win.start.round()));
    }
  }

  void _onWindowChanged(RangeValues v) {
    final cap = _durMs < _maxSpanMs ? _durMs : _maxSpanMs.toDouble();
    var s = v.start, e = v.end;
    if (e - s > cap) {
      // gerakkan thumb yang SEDANG ditarik (yang berubah)
      if (s != _win.start) {
        e = (s + cap).clamp(0, _durMs);
        s = (e - cap).clamp(0, _durMs);
      } else {
        s = (e - cap).clamp(0, _durMs);
        e = (s + cap).clamp(0, _durMs);
      }
    }
    setState(() {
      _win = RangeValues(s, e);
      if (_coverMs < s || _coverMs > e) _coverMs = (s + e) / 2;
    });
    _scheduleCoverRefresh();
  }

  void _scheduleCoverRefresh() {
    _coverDebounce?.cancel();
    _coverDebounce = Timer(const Duration(milliseconds: 350), _refreshCover);
  }

  Future<void> _refreshCover() async {
    final src = _srcPath;
    if (src == null) return;
    final seq = ++_coverSeq;
    try {
      final tmp = await getTemporaryDirectory();
      final out = '${tmp.path}/livephoto_cover_$seq.jpg';
      final path = await LivePhotoTool.cover(
        path: src,
        timeUs: (_coverMs * 1000).round(),
        outPath: out,
        matrix: _preset.matrix,
      );
      if (!mounted || seq != _coverSeq) return; // cuma pakai hasil terbaru
      setState(() => _coverPath = path);
    } catch (_) {
      // cover gagal = bukan akhir dunia; klip tetap bisa diproses
    }
  }

  Future<void> _process() async {
    final src = _srcPath;
    if (src == null || _processing) return;
    setState(() {
      _processing = true;
      _prog = 0;
    });
    Timer? timer;
    try {
      final tmp = await getTemporaryDirectory();
      final out = '${tmp.path}/dykal_live_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final fut = LivePhotoTool.start(
        inPath: src,
        outPath: out,
        startMs: _win.start.round(),
        endMs: _win.end.round(),
        height: 720, // kompres ringan: maks 720p (target spek: <=8MB utk 30 dtk)
        matrix: _preset.matrix,
      );
      timer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
        final p = await LivePhotoTool.progress();
        if (p.available && mounted) setState(() => _prog = p.progress / 100);
      });
      final res = await fut;
      final size = res['size'] is num ? (res['size'] as num).toInt() : 0;
      if (!mounted) return;
      setState(() {
        _processing = false;
        _outPath = (res['outPath'] as String?) ?? out;
        _outSize = size;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        _toast('Gagal memproses: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        _toast('Gagal memproses: $e');
      }
    } finally {
      timer?.cancel();
    }
  }

  Future<void> _saveToGallery() async {
    final out = _outPath;
    if (out == null) return;
    try {
      await PhotoManager.editor.saveVideo(
        File(out),
        title: 'DyKal Live ${DateTime.now().millisecondsSinceEpoch}',
      );
      _toast('Tersimpan di galeri');
    } catch (e) {
      _toast('Gagal menyimpan: $e');
    }
  }

  Future<void> _share() async {
    final out = _outPath;
    if (out == null) return;
    try {
      // pola sama persis dengan share foto album (fullscreen_media_viewer)
      await Share.shareXFiles([XFile(out)], text: 'Live moment dari DyKal');
    } catch (e) {
      _toast('Gagal membagikan: $e');
    }
  }

  /// FASE 2 (Batch K): kemas cover+klip jadi Motion Photo (format Google).
  /// Struktur byte dirangkai pure-Dart di MotionPhotoWriter — tanpa native.
  Future<void> _saveAsLivePhoto() async {
    final out = _outPath;
    final cover = _coverPath;
    if (out == null) {
      _toast('Proses dulu videonya');
      return;
    }
    if (cover == null) {
      _toast('Cover belum dirender — geser-slider/tunggu sebentar');
      return;
    }
    try {
      final jpeg = await File(cover).readAsBytes();
      final mp4 = await File(out).readAsBytes();
      // Konvensi Google: timestamp cover relatif ke AKHIR klip (negatif).
      final clipDurUs = ((_win.end - _win.start) * 1000).round();
      final coverInClipUs = ((_coverMs - _win.start) * 1000).round();
      final data = MotionPhotoWriter.build(
        jpeg: jpeg,
        mp4: mp4,
        presentationTimestampUs: coverInClipUs - clipDurUs,
      );
      await PhotoManager.editor.saveImage(
        data,
        title: 'DyKal LivePhoto ${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      _toast('Live Photo tersimpan — lihat badge muternya di Google Photos');
    } catch (e) {
      _toast('Gagal menyimpan Live Photo: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.surfaceDark,
      appBar: AppBar(
        title: const Text('Live Photo'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          if (_srcPath == null) _buildEmpty() else _buildEditor(),
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: _prog > 0 ? _prog : null, minHeight: 6),
                    const SizedBox(height: 12),
                    Text(
                      _prog > 0
                          ? 'Memangkas & mengompres... ${(100 * _prog).round()}%'
                          : 'Menyiapkan mesin video...',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.motion_photos_on_rounded, size: 84, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            const Text(
              'Ubah video jadi "momen hidup"',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih MP4 dari galeri, geser slider buat milih potongan (maks 30 detik), '
              'oles preset, lalu simpan atau bagikan. Semua diproses di HP-mu — tanpa server.',
              style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_rounded),
              label: const Text('Pilih Video dari Galeri'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final c = _c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // --- preview ---
        if (c != null && c.value.isInitialized)
          GestureDetector(
            onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(c),
                    if (!c.value.isPlaying)
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // --- trim ---
        _card(
          title: 'Potongan momen (maks 30 detik)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RangeSlider(
                values: RangeValues(
                  _win.start.clamp(0, _durMs),
                  _win.end.clamp(0, _durMs),
                ),
                min: 0,
                max: _durMs <= 0 ? 1 : _durMs,
                onChangeStart: (_) => _scrubbing = true,
                onChangeEnd: (_) {
                  _scrubbing = false;
                  _c?.seekTo(Duration(milliseconds: _win.start.round()));
                },
                onChanged: _onWindowChanged,
              ),
              Text(
                '${_fmt(_win.start)} sampai ${_fmt(_win.end)}  ·  ${_fmt(_win.end - _win.start)} terpilih',
                style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- cover + preset ---
        _card(
          title: 'Foto cover & suasana',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      height: 128,
                      child: _coverPath != null
                          ? Image.file(
                              File(_coverPath!),
                              key: ValueKey(_coverPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _coverFallback(),
                            )
                          : _coverFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geser buat milih frame cover. Preset di bawah dioles ke cover DAN klip (satu rasa).',
                          style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cover: ${_fmt(_coverMs)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Slider(
                value: _coverMs.clamp(_win.start, _win.end),
                min: _win.start,
                max: _win.end <= _win.start ? _win.start + 1 : _win.end,
                onChanged: (v) {
                  setState(() => _coverMs = v);
                  _scheduleCoverRefresh();
                },
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LivePhotoPreset.all.map((p) {
                  final sel = p.id == _preset.id;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _preset = p);
                      _scheduleCoverRefresh();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: _processing ? null : _process,
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: Text(_outPath == null ? 'Proses Live Photo' : 'Proses Ulang'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),

        // --- hasil ---
        if (_outPath != null) ...[
          const SizedBox(height: 16),
          _card(
            title:
                'Siap dipakai — ${(_outSize / (1024 * 1024)).toStringAsFixed(1)} MB, ${_fmt(_win.end - _win.start)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveToGallery,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Simpan Video'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Bagikan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _saveAsLivePhoto,
                    icon: const Icon(Icons.motion_photos_on_rounded),
                    label: const Text('Simpan sebagai Live Photo'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '"Simpan Video" = MP4 polos, siap posting di mana saja. '
                  '"Simpan sebagai Live Photo" = format Motion Photo Google: '
                  'badge LIVE muncul di Google Photos / Samsung Gallery, galeri '
                  'lain tetap menampilkan fotonya. Kirim ke Pasangan (terenkripsi) '
                  'menyusul di Fase 3.',
                  style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _coverFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(Icons.image_rounded, color: Colors.white.withValues(alpha: 0.4)),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
