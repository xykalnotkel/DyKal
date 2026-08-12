import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'story_mood.dart';

/// Katalog musik gratis (Batch I — pengganti "lagu TikTok" yang memang tak
/// bisa di-scrape: TikTok tak menyediakan API publik & scraping melanggar
/// ToS). Dua sumber:
///  1) JSON katalog XYSTUDIO (default: file landing/music/index.json di repo —
///     selalu tersedia, tinggal diedit untuk menambah lagu berlisensi bebas).
///  2) Jamendo (CC) bila owner mengisi client_id di Settings.
class CatalogTrack {
  final String title;
  final String artist;
  final String url;
  final StoryMood mood;
  const CatalogTrack({required this.title, required this.artist, required this.url, required this.mood});
}

class MusicCatalogService {
  static const _prefUrl = 'music_catalog_url';
  static const _prefJamendo = 'jamendo_client_id';
  static const defaultCatalogUrl =
      'https://raw.githubusercontent.com/xykalnotkel/DyKal/main/landing/music/index.json';

  static Future<String> catalogUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefUrl) ?? defaultCatalogUrl;
  }

  static Future<void> setCatalogUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefUrl, url.trim());
  }

  static Future<String> jamendoClientId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefJamendo) ?? '';
  }

  static Future<void> setJamendoClientId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefJamendo, id.trim());
  }

  /// Ambil katalog: JSON lokal-repo + (opsional) Jamendo trending.
  static Future<List<CatalogTrack>> fetch() async {
    final out = <CatalogTrack>[];
    // 1) JSON katalog (skema: {songs:[{title,artist,url,mood}]})
    try {
      final url = await catalogUrl();
      if (url.isNotEmpty) {
        final r = await Dio().get(url).timeout(const Duration(seconds: 12));
        final j = r.data is String ? jsonDecode(r.data as String) : r.data;
        final songs = (j['songs'] as List?) ?? const [];
        for (final s in songs) {
          if (s is! Map) continue;
          final t = '${s['title'] ?? ''}';
          final u = '${s['url'] ?? ''}';
          if (u.isEmpty || !u.startsWith('http')) continue;
          out.add(CatalogTrack(
            title: t.isEmpty ? 'Lagu' : t,
            artist: '${s['artist'] ?? ''}',
            url: u,
            mood: StoryMood.values.firstWhere(
              (m) => m.name == '${s['mood'] ?? ''}',
              orElse: () => StoryMoodAnalyzer.guessFromName(t),
            ),
          ));
        }
      }
    } catch (_) {}

    // 2) Jamendo (opsional — client_id gratis dari dev.jamendo.com)
    try {
      final cid = await jamendoClientId();
      if (cid.isNotEmpty) {
        final r = await Dio().get(
          'https://api.jamendo.com/v3.0/tracks/',
          queryParameters: {
            'client_id': cid,
            'format': 'json',
            'limit': '15',
            'order': 'popularity_total',
            'audioformat': 'mp32',
            'include': 'musicinfo',
          },
        ).timeout(const Duration(seconds: 12));
        final results = (r.data['results'] as List?) ?? const [];
        for (final t in results) {
          final u = '${t['audio'] ?? ''}';
          if (u.isEmpty) continue;
          out.add(CatalogTrack(
            title: '${t['name'] ?? 'Lagu'}',
            artist: '${t['artist_name'] ?? ''}',
            url: u,
            mood: StoryMoodAnalyzer.guessFromName('${t['name'] ?? ''}'),
          ));
        }
      }
    } catch (_) {}
    return out;
  }

  /// Unduh lagu katalog ke penyimpanan app -> dipakai playlist cerita lokal.
  static Future<String?> download(CatalogTrack t) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/story_music');
      if (!await folder.exists()) await folder.create(recursive: true);
      final safe = t.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final dest = File('${folder.path}/${safe.isEmpty ? DateTime.now().millisecondsSinceEpoch : safe}_${t.mood.name}.mp3');
      await Dio().download(t.url, dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }
}
