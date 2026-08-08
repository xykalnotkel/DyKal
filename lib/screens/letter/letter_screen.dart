import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import 'letter_detail_screen.dart';

class LetterScreen extends StatelessWidget {
  const LetterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleId = AuthService().coupleId;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent, elevation: 0, floating: true,
          title: Row(children: [Icon(Icons.mail, size: 20, color: DyKalTheme.textDark), const SizedBox(width: 8), const Text("Surat Cinta")]),
          actions: [IconButton(onPressed: () => _compose(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit, color: Colors.white, size: 18)))],
        ),
        SliverToBoxAdapter(child: _intro()),
        StreamBuilder<QuerySnapshot>(
          stream: coupleId == null ? null : FirebaseFirestore.instance.collection('couples/$coupleId/letters').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
            final docs = snap.data!.docs;
            if (docs.isEmpty) return SliverFillRemaining(child: _empty());
            return SliverList.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final fromName = data['fromName'] as String? ?? 'Ayang';
                final isLoved = data['isLoved'] as bool? ?? false;
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                final text = data['text'] as String? ?? '';
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LetterDetailScreen(text: text, fromName: fromName, createdAt: created))),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: DyKalTheme.primary.withOpacity(0.15), child: Icon(Icons.mail, size: 16, color: DyKalTheme.primary)),
                        const SizedBox(width: 8),
                        Text("Dari $fromName", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => docs[i].reference.update({'isLoved': !isLoved}),
                          child: Icon(Icons.favorite, size: 18, color: isLoved ? DyKalTheme.primary : DyKalTheme.textGrey.withOpacity(0.4)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.5)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.touch_app, size: 12, color: Color(0xFFFF6B8A)),
                        const SizedBox(width: 4),
                        Text("Ketuk untuk membuka surat", style: TextStyle(color: DyKalTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (created != null) Text(_fmt(created), style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11, fontStyle: FontStyle.italic)),
                      ]),
                    ]),
                  ),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _intro() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
        child: Row(children: [
          Image.asset('assets/illustrations/webp/letter.webp', width: 80, height: 80, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.mail, size: 48, color: Color(0xFFFF6B8A))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text("Tulis surat untuk Ayang", style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 6), Icon(Icons.favorite, size: 14, color: DyKalTheme.primary)]),
            const SizedBox(height: 4),
            Text("Ketuk surat untuk membuka dengan segel love ✉️", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
          ])),
        ]),
      );

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.drafts, size: 64, color: DyKalTheme.textGrey.withOpacity(0.4)),
        const SizedBox(height: 12),
        const Text("Belum ada surat", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text("Tulis surat cinta pertama 💌", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
      ]));

  void _compose(BuildContext context) {
    final c = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: DyKalTheme.borderSoft, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Tulis Surat Cinta", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 6, decoration: InputDecoration(hintText: "Tulis isi hatimu disini...", filled: true, fillColor: DyKalTheme.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () async {
              final text = c.text.trim();
              if (text.isEmpty) return;
              final auth = AuthService();
              final coupleId = auth.coupleId;
              if (coupleId == null) return;
              await FirebaseFirestore.instance.collection('couples/$coupleId/letters').add({
                'text': text,
                'fromId': auth.myId,
                'fromName': auth.myName,
                'isLoved': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Surat terkirim 💕")));
              }
            },
            icon: const Icon(Icons.send), label: const Text("Kirim Surat"),
          )),
        ]),
      ),
    );
  }

  String _fmt(DateTime d) => "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
}
