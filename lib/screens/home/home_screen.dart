import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../services/wallpaper_settings.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/story_avatar.dart';
import '../call/call_log_screen.dart';
import 'story_viewer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Cap waktu terakhir pusat notifikasi dibaca — dasar badge lonceng.
  int _notifSeenMs = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getInt(NotificationsScreen.seenKey) ?? 0;
      if (mounted) setState(() => _notifSeenMs = v);
    });
  }

  /// Nama pasangan: jika saya member A (pembuat couple), pasangan ada di
  /// displayNameB; jika saya member B (yang join), pasangan ada di displayNameA.
  String _partnerName(Map<String, dynamic>? d) {
    if (d == null) return '';
    final myId = AuthService().myId;
    final createdBy = d['createdBy'] as String?;
    final isMemberA = createdBy == myId;
    return (isMemberA ? d['displayNameB'] : d['displayNameA']) as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return ListenableBuilder(
      listenable: WallpaperSettings.instance,
      builder: (context, _) {
        // Latar beranda kustom (foto dari galeri) — fitur Batch C.
        // Overlay lembut diberi agar konten tetap kebaca di atas foto apa pun.
        final homeBg = WallpaperSettings.instance.homePath;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: homeBg != null && File(homeBg).existsSync()
              ? BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(File(homeBg)),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      (dark ? Colors.black : Colors.white).withValues(alpha: dark ? 0.72 : 0.78),
                      dark ? BlendMode.darken : BlendMode.lighten,
                    ),
                  ),
                )
              : null,
          child: CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: DyKalTheme.dykalGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DyKal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  StreamBuilder<DocumentSnapshot>(
                    stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
                    builder: (context, snap) {
                      final d = snap.data?.data() as Map<String, dynamic>?;
                      final name = _partnerName(d);
                      return Text(
                        'Kamu & ${name.isNotEmpty ? name : 'Dia'}',
                        style: TextStyle(fontSize: 11, color: DyKalTheme.textSecondaryOf(context)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            _notifBell(context),
            _chatButton(context),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallLogScreen())),
              tooltip: 'Log Panggilan',
              icon: Icon(Icons.phone_in_talk_outlined, color: DyKalTheme.textPrimaryOf(context)),
            ),
            const SizedBox(width: 4),
          ],
        ),

        // Hero Card
        SliverToBoxAdapter(child: _hero(context)),

        // Status Online Pasangan & Tombol Panggilan Cepat
        SliverToBoxAdapter(child: _partnerStatus()),
        SliverToBoxAdapter(child: _quickCall(context)),

        // Cerita Album (WhatsApp Segmented Story Style)
        const SliverToBoxHeader(label: 'Cerita Album'),
        SliverToBoxAdapter(child: _storiesRow(context)),

        // Anniversary & Ultah
        SliverToBoxAdapter(child: _anniversary()),
        SliverToBoxAdapter(child: _birthday()),

        // Statistik
        const SliverToBoxHeader(label: 'Statistik Kalian'),
        SliverToBoxAdapter(child: _stats(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
          ),
        );
      },
    );
  }

  Widget _partnerStatus() {
    final partnerId = AuthService().partnerId ?? '';
    if (partnerId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc('presence/$partnerId').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final online = d?['isOnline'] ?? false;
        final lastSeen = d?['lastSeen'];
        String sub = online ? 'Sedang online' : 'Offline';
        if (!online && lastSeen is Timestamp) {
          final dt = lastSeen.toDate();
          sub = 'Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (online ? DyKalTheme.online : DyKalTheme.textSecondaryOf(context)).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: online ? DyKalTheme.online : DyKalTheme.textSecondaryOf(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: online ? DyKalTheme.online : DyKalTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickCall(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _qaBtn(
              context,
              Icons.call,
              'Telepon Suara',
              DyKalTheme.online,
              () => Navigator.pushNamed(context, '/audioCall', arguments: {'isCaller': true, 'type': 'audio'}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _qaBtn(
              context,
              Icons.videocam,
              'Telepon Video',
              DyKalTheme.primary,
              () => Navigator.pushNamed(context, '/videoCall', arguments: {'isCaller': true, 'type': 'video'}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qaBtn(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _storiesRow(BuildContext context) {
    final coupleId = AuthService().coupleId ?? '';
    final partnerPhoto = AuthService().partnerPhotoUrl;
    final partnerName = AuthService().partnerName ?? 'Dia';
    // Home hanya menampilkan cerita (story) — foto/album dibuka lewat tab Album.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 110,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('couples/$coupleId/albums').snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Satu entri cerita -> membuka StoryViewer (semua foto album)
                Column(
                  children: [
                    StoryAvatar(
                      imageUrl: partnerPhoto,
                      fallbackText: partnerName.isNotEmpty ? partnerName[0] : 'D',
                      storyCount: docs.length,
                      allSeen: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StoryViewer(coupleId: coupleId)),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cerita Kita',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Lonceng notifikasi + badge jumlah belum dibaca:
  /// = (ada update tersedia ? 1 : 0) + pengumuman lebih baru dari last-seen.
  /// Menu baru di topbar sesuai permintaan owner ("lumayan penting buat
  /// info update dll").
  Widget _notifBell(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService.instance,
      builder: (context, _) {
        final updateCount = UpdateService.instance.availableUpdate != null ? 1 : 0;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            var unseen = updateCount;
            for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
              final ts = (d.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ts != null && ts.millisecondsSinceEpoch > _notifSeenMs) unseen++;
            }
            return IconButton(
              tooltip: 'Notifikasi',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
                // Refresh badge setelah layar notif ditutup.
                final p = await SharedPreferences.getInstance();
                if (mounted) setState(() => _notifSeenMs = p.getInt(NotificationsScreen.seenKey) ?? 0);
              },
              icon: Badge(
                isLabelVisible: unseen > 0,
                label: Text('$unseen'),
                backgroundColor: DyKalTheme.primary,
                child: Icon(Icons.notifications_outlined, color: DyKalTheme.textPrimaryOf(context)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chatButton(BuildContext context) {
    final coupleId = AuthService().coupleId;
    final myId = AuthService().myId;
    return StreamBuilder<QuerySnapshot>(
      stream: (coupleId == null || myId.isEmpty)
          ? null
          : FirebaseFirestore.instance.collection('chats/$coupleId/messages').snapshots(),
      builder: (_, snap) {
        final unread = snap.data?.docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              return m['fromId'] != myId && m['status'] != 'read';
            }).length ??
            0;
        return IconButton(
          onPressed: () => Navigator.pushNamed(context, '/chat'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.chat_bubble_outline, color: DyKalTheme.textPrimaryOf(context)),
              if (unread > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(color: DyKalTheme.primary, shape: BoxShape.circle),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DyKalTheme.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DyKalTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Hai, Kalian Berdua', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(width: 6),
                    const Icon(Icons.favorite, color: DyKalTheme.primary, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Semoga harimu indah. Sapa dia sekarang.', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 13)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/chat'),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('Mulai Chat'),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/illustrations/home_hero_couple.webp',
            width: 130,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: 100, height: 100),
          ),
        ],
      ),
    );
  }

  Widget _anniversary() {
    final coupleId = AuthService().coupleId;
    return StreamBuilder<DocumentSnapshot>(
      stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final ann = d == null ? null : (d['anniversary'] as Timestamp?)?.toDate();
        String subtitle = 'Atur tanggal anniversary di Profil';
        String title = 'Anniversary Kalian';
        int days = 0;
        if (ann != null) {
          days = DateTime.now().difference(ann).inDays;
          title = 'Hari ke-${days < 0 ? 0 : days} Bersama';
          DateTime next = DateTime(DateTime.now().year, ann.month, ann.day);
          if (next.isBefore(DateTime.now())) next = DateTime(DateTime.now().year + 1, ann.month, ann.day);
          final left = next.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
          subtitle = '${ann.day}/${ann.month}/${ann.year} • $left hari lagi ke tahun depan';
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DyKalTheme.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DyKalTheme.secondary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/illustrations/webp/anniversary.webp',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => SizedBox(width: 60, height: 60, child: Icon(Icons.cake, color: DyKalTheme.secondary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available, color: DyKalTheme.secondary, size: 16),
                        const SizedBox(width: 6),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _birthday() {
    final coupleId = AuthService().coupleId;
    return StreamBuilder<DocumentSnapshot>(
      stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        if (d == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final bA = (d['birthdayA'] as Timestamp?)?.toDate();
        final bB = (d['birthdayB'] as Timestamp?)?.toDate();
        final nameA = d['displayNameA'] as String? ?? '';
        final nameB = d['displayNameB'] as String? ?? '';
        final isBA = bA != null && bA.month == now.month && bA.day == now.day;
        final isBB = bB != null && bB.month == now.month && bB.day == now.day;
        if (!isBA && !isBB) return const SizedBox.shrink();
        final who = isBA ? nameA : nameB;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: DyKalTheme.loveGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: DyKalTheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/illustrations/webp/birthday.webp',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.cake, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selamat Ulang Tahun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Hari ini ulang tahun $who. Kirim ucapan yuk.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stats(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _stat(context, Icons.chat, () => _countStream('chats/$coupleId/messages'), 'Chat'),
          const SizedBox(width: 12),
          _stat(context, Icons.collections, () => _countStream('couples/$coupleId/albums'), 'Album'),
          const SizedBox(width: 12),
          _stat(context, Icons.mail, () => _countStream('couples/$coupleId/letters'), 'Surat'),
        ],
      ),
    );
  }

  Stream<int> _countStream(String path) =>
      FirebaseFirestore.instance.collection(path).snapshots().map((s) => s.docs.length);

  Widget _stat(BuildContext context, IconData icon, Stream<int> Function() stream, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DyKalTheme.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DyKalTheme.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(icon, color: DyKalTheme.primary, size: 22),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: stream(),
              builder: (_, s) => Text('${s.data ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            Text(label, style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class SliverToBoxHeader extends StatelessWidget {
  final String label;
  const SliverToBoxHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: DyKalTheme.primary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      );
}
