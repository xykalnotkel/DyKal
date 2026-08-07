import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/theme.dart';
import '../../services/birthday_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? birthdayToday;

  @override
  void initState() {
    super.initState();
    _checkBirthday();
  }

  Future<void> _checkBirthday() async {
    final res = await BirthdayService().checkTodayIsBirthday();
    if (res != null) setState(() => birthdayToday = res);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // TOPBAR SEAMLESS - Tanpa garis, background nyatu
        SliverAppBar(
          floating: true,
          pinned: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: DyKalTheme.dykalGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: Colors.white, size: 18),
              ),
              SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("DyKal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text("Kamu & Dia • 365 hari", style: TextStyle(fontSize: 11, color: DyKalTheme.textGrey)),
              ]),
            ],
          ),
          actions: [
            IconButton(onPressed: (){}, icon: Icon(PhosphorIcons.bell(PhosphorIconsStyle.regular), color: DyKalTheme.textDark)),
            IconButton(onPressed: (){}, icon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.regular), color: DyKalTheme.textDark)),
            SizedBox(width: 8),
          ],
        ),

        // BIRTHDAY BANNER OTOMATIS - Custom size 80x80
        if (birthdayToday != null)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: DyKalTheme.loveGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: DyKalTheme.primary.withOpacity(0.3), blurRadius: 20, offset: Offset(0,8))],
              ),
              child: Row(children: [
                Image.asset('assets/illustrations/webp/birthday.webp', width: 80, height: 80, fit: BoxFit.contain),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(PhosphorIcons.cake(PhosphorIconsStyle.fill), color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text("Selamat Ulang Tahun", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                  SizedBox(height: 4),
                  Text("Hari ini ulang tahun ${birthdayToday!['who']}. Kirim surat cinta yuk", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                ])),
              ]),
            ),
          ),

        // HERO CARD - Ilustrasi custom 110x110
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DyKalTheme.borderSoft),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("Hai, Kalian Berdua", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  SizedBox(width: 6),
                  Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: DyKalTheme.primary, size: 18),
                ]),
                SizedBox(height: 6),
                Text("Semoga harimu indah. Sudah kirim kabar ke dia hari ini?", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 13)),
                SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: (){},
                  icon: Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill), size: 16),
                  label: Text("Kirim Surat"),
                ),
              ])),
              Image.asset('assets/illustrations/webp/home_hero.webp', width: 110, height: 110, fit: BoxFit.contain),
            ]),
          ),
        ),

        // ONBOARDING / ANNIVERSARY CARD - Ilustrasi custom 100x100
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DyKalTheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DyKalTheme.secondary.withOpacity(0.15)),
            ),
            child: Row(children: [
              Image.asset('assets/illustrations/webp/anniversary.webp', width: 72, height: 72, fit: BoxFit.contain),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill), color: DyKalTheme.secondary, size: 16),
                  SizedBox(width: 6),
                  Text("365 Hari Bersama", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                SizedBox(height: 4),
                Text("Anniversary kalian 14 Feb • 191 hari lagi", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
              ])),
              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.regular), color: DyKalTheme.textGrey, size: 18),
            ]),
          ),
        ),

        // QUICK STATS - Icons modern rounded
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              _statCard(PhosphorIcons.chatCircle(PhosphorIconsStyle.regular), "1.2k", "Chat"),
              SizedBox(width: 12),
              _statCard(PhosphorIcons.images(PhosphorIconsStyle.regular), "342", "Foto"),
              SizedBox(width: 12),
              _statCard(PhosphorIcons.envelopeSimple(PhosphorIconsStyle.regular), "48", "Surat"),
            ]),
          ),
        ),

        // MEMORY TIMELINE - Icons rounded
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular), size: 18, color: DyKalTheme.textDark),
              SizedBox(width: 8),
              Text("Kenangan Terakhir", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
          ),
        ),
        SliverList.builder(
          itemCount: 3,
          itemBuilder: (_, i) => Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(width: 60, height: 60, color: DyKalTheme.borderSoft, child: Icon(PhosphorIcons.image(PhosphorIconsStyle.regular), color: DyKalTheme.textGrey))),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("Pantai Selong", style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(PhosphorIcons.camera(PhosphorIconsStyle.fill), size: 12, color: DyKalTheme.textGrey),
                ]),
                Text("7 Agustus 2026 • 2 foto baru", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
              ])),
              Icon(PhosphorIcons.heart(PhosphorIconsStyle.regular), color: DyKalTheme.primary, size: 20),
            ]),
          ),
        ),

        // PRIVATE SECURE CARD - Ilustrasi love_lock 56x56
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
            child: Row(children: [
              Image.asset('assets/illustrations/webp/love_lock.webp', width: 56, height: 56, fit: BoxFit.contain),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(PhosphorIcons.lockKey(PhosphorIconsStyle.fill), size: 14, color: DyKalTheme.primary),
                  SizedBox(width: 6),
                  Text("Private & Aman", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                Text("Hanya kalian berdua yang bisa lihat", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
              ])),
              Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: DyKalTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), size: 12, color: DyKalTheme.success), SizedBox(width: 4), Text("Terenkripsi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DyKalTheme.success))])),
            ]),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Expanded(child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        Icon(icon, color: DyKalTheme.primary, size: 22),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
      ]),
    ));
  }
}
