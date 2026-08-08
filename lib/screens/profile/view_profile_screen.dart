import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

/// Fullscreen View Profile pasangan.
class ViewProfileScreen extends StatelessWidget {
  final String partnerId;
  const ViewProfileScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.doc('users/$partnerId').snapshots(),
        builder: (_, snap) {
          final d = snap.data?.data() as Map<String, dynamic>?;
          final name = d?['displayName'] ?? '';
          final email = d?['email'] ?? '';
          final photo = d?['photoUrl'] as String?;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Column(children: [
            // Top bar
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
              const Spacer(),
            ])),

            // Photo + Name
            const SizedBox(height: 20),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: DyKalTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: DyKalTheme.primary, width: 2),
              ),
              child: photo != null
                ? ClipOval(child: CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover))
                : Center(child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: DyKalTheme.primary))),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (email.toString().isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.email, size: 14, color: DyKalTheme.textGrey),
                const SizedBox(width: 6),
                Flexible(child: Text(email, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ]),

            // Online status
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('presence/$partnerId').snapshots(),
              builder: (_, ps) {
                final pd = ps.data?.data() as Map<String, dynamic>?;
                final online = pd?['isOnline'] ?? false;
                final lastSeen = pd?['lastSeen'];
                String statusText = online ? 'Online' : 'Offline';
                if (!online && lastSeen is Timestamp) {
                  final dt = lastSeen.toDate();
                  statusText = 'Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: (online ? DyKalTheme.online : DyKalTheme.textGrey).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 8, color: online ? DyKalTheme.online : DyKalTheme.textGrey),
                    const SizedBox(width: 6),
                    Text(statusText, style: TextStyle(color: online ? DyKalTheme.online : DyKalTheme.textGrey, fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                );
              },
            ),

            const Spacer(),

            // Call buttons (sejajar)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
              Expanded(child: _actionButton(Icons.call, 'Telepon', DyKalTheme.online, () {
                Navigator.pushNamed(context, '/audioCall', arguments: {'isCaller': true, 'type': 'audio'});
              })),
              const SizedBox(width: 16),
              Expanded(child: _actionButton(Icons.videocam, 'Video', DyKalTheme.primary, () {
                Navigator.pushNamed(context, '/videoCall', arguments: {'isCaller': true, 'type': 'video'});
              })),
            ])),

            const SizedBox(height: 16),

            // Menu bawah
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
              Expanded(child: _menuButton(Icons.photo_library, 'Media', () {})),
              const SizedBox(width: 8),
              Expanded(child: _menuButton(Icons.block, 'Blokir', () {})),
              const SizedBox(width: 8),
              Expanded(child: _menuButton(Icons.notifications, 'Bisukan', () {})),
            ])),

            const SizedBox(height: 30),
          ]);
        },
      )),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [Icon(icon, color: Colors.white, size: 28), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
      ),
    );
  }

  Widget _menuButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: DyKalTheme.borderSoft)),
        child: Column(children: [Icon(icon, size: 20, color: DyKalTheme.textGrey), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 11, color: DyKalTheme.textGrey))]),
      ),
    );
  }
}
