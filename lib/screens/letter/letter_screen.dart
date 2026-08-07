import 'package:flutter/material.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import '../../config/theme.dart';

class LetterScreen extends StatelessWidget {
  const LetterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(backgroundColor: Colors.transparent, elevation: 0, floating: true, title: Row(children: [Icon(Icons.mail, size: 20, color: DyKalTheme.textDark), SizedBox(width: 8), Text("Surat Cinta")]), actions: [IconButton(onPressed: () => _compose(context), icon: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit, color: Colors.white, size: 18)))]),
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Row(children: [
              Image.asset('assets/illustrations/webp/letter.webp', width: 90, height: 90, fit: BoxFit.contain),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text("Tulis surat untuk Ayang", style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(width: 6), Icon(Icons.favorite, size: 14, color: DyKalTheme.primary)]),
                SizedBox(height: 4),
                Text("Surat akan muncul dengan animasi amplop dan bisa di-love", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
              ])),
            ]),
          ),
        ),
        SliverList.builder(
          itemCount: 3,
          itemBuilder: (_, i) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 16, backgroundColor: DyKalTheme.primary.withOpacity(0.15), child: Icon(Icons.mail, size: 16, color: DyKalTheme.primary)),
                SizedBox(width: 8),
                Text(i == 0 ? "Untuk Ayang • Hari ini" : "Untuk Aku • 2 hari lalu", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Spacer(),
                Icon(Icons.favorite, color: DyKalTheme.primary, size: 16),
              ]),
              SizedBox(height: 10),
              Text("Sayang, hari ini aku kangen banget. Terima kasih sudah jadi yang terbaik buat aku. Peluk jauh", style: TextStyle(fontSize: 14, height: 1.5)),
              SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit_note, size: 12, color: DyKalTheme.textGrey), SizedBox(width: 4), Text("Dy • 07 Aug 2026", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11, fontStyle: FontStyle.italic))])),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _compose(BuildContext context) {
    final c = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: DyKalTheme.borderSoft, borderRadius: BorderRadius.circular(2))),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.mail, size: 18), SizedBox(width: 8), Text("Tulis Surat Cinta", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
        SizedBox(height: 12),
        TextField(controller: c, maxLines: 6, decoration: InputDecoration(hintText: "Tulis isi hatimu disini...", filled: true, fillColor: DyKalTheme.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: (){ Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(Icons.send, color: Colors.white, size: 16), SizedBox(width: 8), Text("Surat terkirim")]))); }, icon: Icon(Icons.send), label: Text("Kirim Surat"))),
      ]),
    ));
  }
}
