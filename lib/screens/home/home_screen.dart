import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _myName(Map<String, dynamic>? d) => d?['displayNameA'] as String? ?? AuthService().myName;
  String _partnerName(Map<String, dynamic>? d) => d?['displayNameB'] as String? ?? 'Ayang';

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.favorite, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("DyKal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              StreamBuilder<DocumentSnapshot>(
                stream: coupleId == null ? null : FirebaseFirestore.instance.doc('couples/$coupleId').snapshots(),
                builder: (context, snap) {
                  final d = snap.data?.data() as Map<String, dynamic>?;
                  final name = _partnerName(d);
                  return Text("Kamu & $name", style: TextStyle(fontSize: 11, color: DyKalTheme.textGrey));
                },
              ),
            ]),
          ]),
          actions: [
            IconButton(onPressed: () => Navigator.pushNamed(context, '/chat'), icon: Icon(Icons.chat_bubble_outline, color: DyKalTheme.textDark)),
            IconButton(onPressed: () => Navigator.pushNamed(context, '/profile'), icon: Icon(Icons.settings, color: DyKalTheme.textDark)),
            const SizedBox(width: 4),
          ],
        ),

        // HERO + tombol Chat
        SliverToBoxAdapter(child: _hero(context)),
        // ANNIVERSARY
        SliverToBoxAdapter(child: _anniversary()),
        // ULTAH
        SliverToBoxAdapter(child: _birthday()),
        // STATISTIK
        SliverToBoxHeader(label: "Statistik Kalian"),
        SliverToBoxAdapter(child: _stats()),
        SliverToBox(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DyKalTheme.borderSoft),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("Hai, Kalian Berdua", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(width: 6),
            Icon(Icons.favorite, color: DyKalTheme.primary, size: 18),
          ]),
          const SizedBox(height: 6),
          Text("Semoga harimu indah. Sapa dia sekarang 💕", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/chat'),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text("Chat dengan Ayang"),
          ),
        ])),
        Image.asset('assets/illustrations/webp/home_hero.webp', width: 110, height: 110, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(width: 110, height: 110)),
      ]),
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
          // hitung ulang tahun anniversary berikutnya
          DateTime next = DateTime(DateTime.now().year, ann.month, ann.day);
          if (next.isBefore(DateTime.now())) next = DateTime(DateTime.now().year + 1, ann.month, ann.day);
          final left = next.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
          subtitle = '${ann.day}/${ann.month}/${ann.year} • $left hari lagi ke tahun depan';
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DyKalTheme.secondary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DyKalTheme.secondary.withOpacity(0.15)),
          ),
          child: Row(children: [
            Image.asset('assets/illustrations/webp/anniversary.webp', width: 64, height: 64, fit: BoxFit.contain, errorBuilder: (_, __, ___) => SizedBox(width: 64, height: 64, child: Icon(Icons.cake, color: DyKalTheme.secondary))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.event_available, color: DyKalTheme.secondary, size: 16),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
            ])),
          ]),
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
        final nameA = d['displayNameA'] as String? ?? 'Aku';
        final nameB = d['displayNameB'] as String? ?? 'Ayang';
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
            boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Image.asset('assets/illustrations/webp/birthday.webp', width: 70, height: 70, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.cake, color: Colors.white, size: 40)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [Icon(Icons.cake, color: Colors.white, size: 18), SizedBox(width: 6), Text("Selamat Ulang Tahun", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))]),
              const SizedBox(height: 4),
              Text("Hari ini ulang tahun $who. Kirim surat cinta yuk 💌", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ])),
          ]),
        );
      },
    );
  }

  Widget _stats() {
    final coupleId = AuthService().coupleId;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        _stat(Icons.chat, () => _countStream('chats/$coupleId/messages'), "Chat"),
        const SizedBox(width: 12),
        _stat(Icons.collections, () => _countStream('couples/$coupleId/album'), "Foto"),
        const SizedBox(width: 12),
        _stat(Icons.mail, () => _countStream('couples/$coupleId/letters'), "Surat"),
      ]),
    );
  }

  // Stream jumlah dokumen sebuah path
  Stream<int> _countStream(String path) => FirebaseFirestore.instance.collection(path).snapshots().map((s) => s.docs.length);

  Widget _stat(IconData icon, Stream<int> Function() stream, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        Icon(icon, color: DyKalTheme.primary, size: 22),
        const SizedBox(height: 8),
        StreamBuilder<int>(
          stream: stream(),
          builder: (_, s) => Text('${s.data ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        Text(label, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
      ]),
    ));
  }
}

/// Header section kecil
class SliverToBoxHeader extends StatelessWidget {
  final String label;
  const SliverToBoxHeader({super.key, required this.label});
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: DyKalTheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
      );
}
