import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../services/update_service.dart';
import '../../widgets/dykal_loading.dart';

/// Pusat Notifikasi — permintaan owner: menu baru di topbar untuk info
/// update & pengumuman. Isinya:
/// 1. KARTU UPDATE: versi terpasang vs versi terbaru + tombol unduh
///    berprogres (sumber kebenaran tetap UpdateService/GitHub Release).
/// 2. PENGUMUMAN XYSTUDIO: koleksi Firestore `announcements/{doc}` —
///    ditulis dari Firebase Console (rules: baca bebas utk user login,
///    tulis ditutup dari client). Cocok buat info maintenance, fitur baru,
///    atau ucapan dari owner.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// Pref key penanda terakhir dibaca (dipakai badge lonceng di Home).
  static const seenKey = 'notif_seen_ms';

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Tandai semua sudah dibaca saat layar dibuka (badge lonceng bersih).
    SharedPreferences.getInstance().then((p) {
      p.setInt(NotificationsScreen.seenKey, DateTime.now().millisecondsSinceEpoch);
    });
    // Pastikan data update segar setiap layar ini dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DyKalTheme.backgroundDark
          : DyKalTheme.background,
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _updateCard(context),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: DyKalTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                'Pengumuman dari XYSTUDIO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DyKalTheme.textSecondaryOf(context),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _announcementList(context),
        ],
      ),
    );
  }

  Widget _updateCard(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService.instance,
      builder: (context, _) {
        final svc = UpdateService.instance;
        final info = svc.availableUpdate;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: info != null ? DyKalTheme.dykalGradient : null,
            color: info == null ? DyKalTheme.cardOf(context) : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: info == null ? DyKalTheme.borderOf(context) : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    info != null ? Icons.system_update_alt : Icons.verified_outlined,
                    color: info != null ? Colors.white : DyKalTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info != null ? 'Update tersedia: v${info.versionName}' : 'Aplikasi versi terbaru',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: info != null ? Colors.white : DyKalTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FutureBuilder<String>(
                future: () async {
                  final p = await PackageInfo.fromPlatform();
                  return 'Terpasang: v${p.version} (${p.buildNumber})';
                }(),
                builder: (_, s) => Text(
                  s.data ?? 'Terpasang: ...',
                  style: TextStyle(
                    fontSize: 12,
                    color: info != null
                        ? Colors.white.withValues(alpha: 0.85)
                        : DyKalTheme.textSecondaryOf(context),
                  ),
                ),
              ),
              if (info != null) ...[
                const SizedBox(height: 12),
                if (svc.isDownloading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: svc.downloadProgress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mengunduh ${(svc.downloadProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DyKalTheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => UpdateService.instance.downloadAndInstall(),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Unduh Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _announcementList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _emptyState(context, 'Belum bisa memuat pengumuman');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: DyKalSpinner(size: 28),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState(context, 'Belum ada pengumuman. Semua info penting akan muncul di sini.');
        }
        return Column(
          children: [
            for (final d in docs)
              _announcementTile(context, d.data() as Map<String, dynamic>),
          ],
        );
      },
    );
  }

  Widget _announcementTile(BuildContext context, Map<String, dynamic> m) {
    final ts = m['createdAt'] as Timestamp?;
    String when = '';
    if (ts != null) {
      final dt = ts.toDate();
      when = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DyKalTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DyKalTheme.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DyKalTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined, size: 16, color: DyKalTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (m['title'] as String?) ?? 'Pengumuman',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: DyKalTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (m['body'] as String?) ?? '',
                  style: TextStyle(fontSize: 12, color: DyKalTheme.textSecondaryOf(context)),
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(when, style: TextStyle(fontSize: 10, color: DyKalTheme.textGrey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 36, color: DyKalTheme.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DyKalTheme.textGrey)),
        ],
      ),
    );
  }
}
