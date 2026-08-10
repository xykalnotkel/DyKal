import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/push_service.dart';
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
          title: Row(children: [Icon(Icons.mail, size: 20, color: DyKalTheme.textPrimaryOf(context)), const SizedBox(width: 8), const Text("Surat Cinta")]),
          actions: [IconButton(onPressed: () => _compose(context), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit, color: Colors.white, size: 18)))],
        ),
        SliverToBoxAdapter(child: _intro(context)),
        StreamBuilder<QuerySnapshot>(
          stream: coupleId == null ? null : FirebaseFirestore.instance.collection('couples/$coupleId/letters').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFF6B8A)))));
            final docs = snap.data!.docs;
            if (docs.isEmpty) return SliverFillRemaining(child: _empty());
            return SliverList.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final fromName = data['fromName'] as String? ?? '';
                final isLoved = data['isLoved'] as bool? ?? false;
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                final text = data['text'] as String? ?? '';
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LetterDetailScreen(text: text, fromName: fromName, createdAt: created))),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: DyKalTheme.cardOf(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: DyKalTheme.borderOf(context)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Header amplop: pengirim + tanggal + segel love
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: DyKalTheme.primary.withValues(alpha: 0.07),
                          child: Row(children: [
                            CircleAvatar(radius: 15, backgroundColor: DyKalTheme.primary, child: Text(fromName.isNotEmpty ? fromName[0] : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text("Surat dari $fromName", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              if (created != null) Text(_fmt(created), style: TextStyle(color: DyKalTheme.textGrey, fontSize: 10)),
                            ])),
                            GestureDetector(
                              onTap: () {
                                docs[i].reference.update({'isLoved': !isLoved});
                                if (!isLoved && data['fromId'] != AuthService().myId) {
                                  PushService.notifyPartner(title: AuthService().myName, body: 'Menyukai suratmu', type: 'letter');
                                }
                              },
                              child: Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: isLoved ? DyKalTheme.primary : Colors.transparent, border: Border.all(color: isLoved ? DyKalTheme.primary : DyKalTheme.borderOf(context))),
                                child: Icon(Icons.favorite, size: 16, color: isLoved ? Colors.white : DyKalTheme.textGrey),
                              ),
                            ),
                          ]),
                        ),
                        // Body stationery (preview)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.6, color: DyKalTheme.textPrimaryOf(context))),
                            const SizedBox(height: 10),
                            Row(children: [
                              Icon(Icons.auto_awesome, size: 12, color: DyKalTheme.primary),
                              const SizedBox(width: 4),
                              Text("Ketuk untuk membuka surat", style: TextStyle(color: DyKalTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
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

  Widget _intro(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: DyKalTheme.cardOf(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
        child: Row(children: [
          Image.asset('assets/illustrations/webp/letter.webp', width: 80, height: 80, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.mail, size: 48, color: Color(0xFFFF6B8A))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text("Tulis Surat", style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 6), Icon(Icons.favorite, size: 14, color: DyKalTheme.primary)]),
            const SizedBox(height: 4),
            Text("Ketuk surat untuk membuka dengan segel love", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
          ])),
        ]),
      );

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.drafts, size: 64, color: DyKalTheme.textGrey.withValues(alpha: 0.4)),
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
          TextField(controller: c, maxLines: 6, decoration: InputDecoration(hintText: "Tulis isi hatimu disini...", filled: true, fillColor: DyKalTheme.cardOf(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
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
                PushService.notifyPartner(title: auth.myName, body: 'Surat baru untukmu', type: 'letter');
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
