import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class CallLogScreen extends StatelessWidget {
  const CallLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Panggilan')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats/$coupleId/messages')
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B8A)));
          final docs = snap.data!.docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return m['type'] == 'system' && (m['text']?.toString().contains('Panggilan') ?? false);
          }).toList();
          docs.sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['createdAt'];
            final tb = (b.data() as Map<String, dynamic>)['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.phone_disabled, size: 56, color: DyKalTheme.textGrey.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('Belum ada riwayat panggilan', style: TextStyle(fontWeight: FontWeight.w600)),
          ]));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final text = m['text'] as String? ?? '';
              final isVideo = text.contains('video');
              final isMissed = text.contains('tidak terjawab');
              final ts = m['createdAt'];
              String timeStr = '';
              if (ts is Timestamp) {
                final dt = ts.toDate();
                timeStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
              }
              return ListTile(
                leading: CircleAvatar(backgroundColor: isMissed ? Colors.red.withValues(alpha: 0.1) : DyKalTheme.primary.withValues(alpha: 0.1),
                  child: Icon(isMissed ? Icons.call_missed : (isVideo ? Icons.videocam : Icons.call), color: isMissed ? Colors.red : DyKalTheme.primary)),
                title: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isMissed ? Colors.red : DyKalTheme.textPrimaryOf(context))),
                subtitle: Text(timeStr, style: const TextStyle(fontSize: 11)),
              );
            },
          );
        },
      ),
    );
  }
}
