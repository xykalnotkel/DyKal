import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/dykal_loading.dart';

/// Riwayat panggilan v2 — membaca couples/{coupleId}/callHistory yang
/// ditulis caller saat panggilan berakhir (bukan lagi menyaring teks
/// "Panggilan" dari pesan sistem yang rapuh). Tiap entri memuat:
/// jenis (audio/video), arah (keluar/masuk), status (dijawab/ditolak/
/// tak terjawab), tanggal-jam, dan DURASI bicara.
class CallLogScreen extends StatelessWidget {
  const CallLogScreen({super.key});

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final hm = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Hari ini $hm';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin $hm';
    return '${dt.day}/${dt.month}/${dt.year} $hm';
  }

  String _fmtDur(int sec) {
    if (sec <= 0) return '';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m == 0) return '$s dtk';
    return '$m mnt $s dtk';
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId ?? '';
    final myId = AuthService().myId;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DyKalTheme.backgroundDark
          : DyKalTheme.background,
      appBar: AppBar(title: const Text('Riwayat Panggilan', style: TextStyle(fontWeight: FontWeight.w700))),
      body: StreamBuilder<QuerySnapshot>(
        stream: coupleId.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('couples/$coupleId/callHistory')
                .orderBy('startedAt', descending: true)
                .limit(100)
                .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const DyKalSpinner();
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_disabled, size: 56, color: DyKalTheme.textGrey.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text('Belum ada riwayat panggilan', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Riwayat mulai tercatat dari versi ini', style: TextStyle(fontSize: 12, color: DyKalTheme.textGrey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final isVideo = m['type'] == 'video';
              final status = m['status'] as String? ?? 'missed'; // answered/declined/missed
              final outgoing = m['callerId'] == myId;
              final name = m['callerName'] as String? ?? '';
              final durSec = (m['durationSec'] as num?)?.toInt() ?? 0;
              final startTs = m['startedAt'];
              final dateStr = startTs is Timestamp ? _fmtDate(startTs.toDate()) : '';

              final (icon, color, label) = switch (status) {
                'answered' => (
                    outgoing ? (isVideo ? Icons.video_call : Icons.call_made) : (isVideo ? Icons.video_call : Icons.call_received),
                    DyKalTheme.online,
                    'Dijawab',
                  ),
                'declined' => (Icons.call_end, Colors.orange, 'Ditolak'),
                _ => (Icons.call_missed, Colors.redAccent, 'Tak terjawab'),
              };

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Row(
                  children: [
                    Icon(isVideo ? Icons.videocam_outlined : Icons.call_outlined, size: 13, color: DyKalTheme.textGrey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        outgoing ? 'Kamu menelepon' : (name.isNotEmpty ? name : 'Panggilan masuk'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: status == 'missed' ? Colors.redAccent : DyKalTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  [
                    label,
                    dateStr,
                    if (durSec > 0) _fmtDur(durSec),
                  ].where((e) => e.isNotEmpty).join(' • '),
                  style: TextStyle(fontSize: 11.5, color: DyKalTheme.textSecondaryOf(context)),
                ),
                trailing: Icon(isVideo ? Icons.videocam : Icons.call, size: 20, color: DyKalTheme.primary),
              );
            },
          );
        },
      ),
    );
  }
}
