import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../config/theme.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  bool isCreating = true; // tab: buat kode vs masukkan kode
  String myCode = "DYKAL-8X7A"; // generate dari Firestore

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(height: 8),
              // Header seamless
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Text("DyKal Pairing", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Spacer(),
                IconButton(onPressed: ()=> Navigator.pop(context), icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.regular), color: DyKalTheme.textDark)),
              ]),
              SizedBox(height: 16),

              // Illustrasi Pairing hero - custom 260x140
              Image.asset('assets/illustrations/webp/pairing.webp', width: 320, height: 160, fit: BoxFit.contain),
              SizedBox(height: 12),

              Text(
                isCreating ? "Hubungkan dengan Pasangan" : "Masukkan Kode Pasangan",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Poppins'),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                isCreating
                    ? "Bagikan kode ini ke Ayang untuk menghubungkan akun kalian. Hanya berdua."
                    : "Masukkan kode yang dibagikan Ayang untuk terhubung.",
                style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Tab switcher - Icons modern rounded Border vs Fill
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderSoft)),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: ()=> setState(()=> isCreating = true),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCreating ? DyKalTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(isCreating ? PhosphorIcons.shareNetwork(PhosphorIconsStyle.fill) : PhosphorIcons.shareNetwork(PhosphorIconsStyle.regular), size: 16, color: isCreating ? Colors.white : DyKalTheme.textGrey),
                        SizedBox(width: 6),
                        Text("Buat Kode", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isCreating ? Colors.white : DyKalTheme.textGrey)),
                      ]),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: ()=> setState(()=> isCreating = false),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isCreating ? DyKalTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(!isCreating ? PhosphorIcons.signIn(PhosphorIconsStyle.fill) : PhosphorIcons.signIn(PhosphorIconsStyle.regular), size: 16, color: !isCreating ? Colors.white : DyKalTheme.textGrey),
                        SizedBox(width: 6),
                        Text("Masuk Kode", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: !isCreating ? Colors.white : DyKalTheme.textGrey)),
                      ]),
                    ),
                  )),
                ]),
              ),
              SizedBox(height: 20),

              if (isCreating) ...[
                // Kartu kode - dengan ilustrasi pairing_code 120x70 sebagai hiasan
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
                  child: Column(children: [
                    Row(children: [
                      Icon(PhosphorIcons.qrCode(PhosphorIconsStyle.regular), color: DyKalTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text("Kode Pairing Kamu", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Spacer(),
                      Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: DyKalTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular), size: 12, color: DyKalTheme.success), SizedBox(width: 4), Text("Aktif 24 jam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DyKalTheme.success))])),
                    ]),
                    SizedBox(height: 14),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.primary.withOpacity(0.2), width: 1.5)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(myCode, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 4, fontFamily: 'Poppins')),
                          ]),
                        ),
                        Positioned(right: 8, top: 8, child: Image.asset('assets/illustrations/webp/pairing_code.webp', width: 52, height: 52, fit: BoxFit.contain, opacity: AlwaysStoppedAnimation(0.9))),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: (){
                        Clipboard.setData(ClipboardData(text: myCode));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Colors.white, size: 16), SizedBox(width: 8), Text("Kode disalin")]))));
                      }, icon: Icon(PhosphorIcons.copy(PhosphorIconsStyle.regular), size: 16), label: Text("Salin"))),
                      SizedBox(width: 10),
                      Expanded(child: FilledButton.icon(onPressed: (){}, icon: Icon(PhosphorIcons.shareNetwork(PhosphorIconsStyle.regular), size: 16), label: Text("Bagikan"))),
                    ]),
                  ]),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: DyKalTheme.secondary.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.secondary.withOpacity(0.15))),
                  child: Row(children: [
                    Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), color: DyKalTheme.secondary, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Private hanya berdua", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text("Kode hanya bisa dipakai sekali dan expired otomatis", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
                    ])),
                  ]),
                ),
              ] else ...[
                // Input kode
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
                  child: Column(children: [
                    Image.asset('assets/illustrations/webp/pairing_code.webp', width: 140, height: 80, fit: BoxFit.contain),
                    SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 6, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "DYKAL-XXXX",
                        hintStyle: TextStyle(letterSpacing: 4, color: DyKalTheme.textGrey.withOpacity(0.5)),
                        filled: true, fillColor: DyKalTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: (){
                      if (_codeController.text.trim().length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Masukkan kode yang valid")));
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(PhosphorIcons.link(PhosphorIconsStyle.regular), color: Colors.white, size: 16), SizedBox(width: 8), Text("Menghubungkan...")]))); 
                    }, icon: Icon(PhosphorIcons.link(PhosphorIconsStyle.regular), size: 16), label: Text("Hubungkan Sekarang"))),
                  ]),
                ),
              ],

              SizedBox(height: 20),
              Row(children: [
                Icon(PhosphorIcons.info(PhosphorIconsStyle.regular), size: 14, color: DyKalTheme.textGrey),
                SizedBox(width: 6),
                Expanded(child: Text("Butuh bantuan? Hubungkan kedua HP di ruangan yang sama untuk scan QR lebih cepat.", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11))),
              ]),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
