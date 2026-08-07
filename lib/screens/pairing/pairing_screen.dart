import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'; // phosphor replaced with Material Icons
import '../../config/theme.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  bool isCreating = true;
  String myCode = "DYKAL-8X7A";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(height: 8),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.favorite, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Text("DyKal Pairing", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: Color(0xFF1A1C1E))),
              ]),
              SizedBox(height: 16),
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
                style: TextStyle(color: Color(0xFF8E9099), fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF1E8EA))),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => isCreating = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCreating ? DyKalTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(isCreating ? Icons.share : Icons.share, size: 16, color: isCreating ? Colors.white : const Color(0xFF8E9099)),
                        SizedBox(width: 6),
                        Text("Buat Kode", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isCreating ? Colors.white : const Color(0xFF8E9099))),
                      ]),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => isCreating = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isCreating ? DyKalTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(!isCreating ? Icons.login : Icons.login, size: 16, color: !isCreating ? Colors.white : const Color(0xFF8E9099)),
                        SizedBox(width: 6),
                        Text("Masuk Kode", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: !isCreating ? Colors.white : const Color(0xFF8E9099))),
                      ]),
                    ),
                  )),
                ]),
              ),
              SizedBox(height: 20),
              if (isCreating) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1E8EA)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.qr_code, color: DyKalTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text("Kode Pairing Kamu", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF4ECDC4).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.history, size: 12, color: Color(0xFF4ECDC4)), SizedBox(width: 4), Text("Aktif 24 jam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4ECDC4)))])),
                    ]),
                    SizedBox(height: 14),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFF6B8A).withOpacity(0.2), width: 1.5)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(myCode, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 4, fontFamily: 'Poppins')),
                          ]),
                        ),
                        Positioned(right: 8, top: 8, child: Image.asset('assets/illustrations/webp/pairing_code.webp', width: 52, height: 52, fit: BoxFit.contain, opacity: const AlwaysStoppedAnimation(0.9))),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () {
                        Clipboard.setData(ClipboardData(text: myCode));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode disalin")));
                      }, icon: Icon(Icons.content_copy, size: 16), label: Text("Salin"))),
                      SizedBox(width: 10),
                      Expanded(child: FilledButton.icon(onPressed: () {}, icon: Icon(Icons.share, size: 16), label: Text("Bagikan"))),
                    ]),
                  ]),
                ),
                SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF7B6CF6).withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF7B6CF6).withOpacity(0.15))),
                  child: Row(children: [
                    Icon(Icons.verified_user, color: Color(0xFF7B6CF6), size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Private hanya berdua", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text("Kode hanya bisa dipakai sekali dan expired otomatis", style: TextStyle(color: Color(0xFF8E9099), fontSize: 11)),
                    ])),
                  ]),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1E8EA))),
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
                        hintStyle: TextStyle(letterSpacing: 4, color: const Color(0xFF8E9099).withOpacity(0.5)),
                        filled: true, fillColor: DyKalTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: () {
                        if (_codeController.text.trim().length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masukkan kode yang valid")));
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menghubungkan...")));
                      },
                      icon: Icon(Icons.link, size: 16),
                      label: Text("Hubungkan Sekarang"),
                    )),
                  ]),
                ),
              ],
              SizedBox(height: 20),
              Row(children: [
                Icon(Icons.info, size: 14, color: Color(0xFF8E9099)),
                SizedBox(width: 6),
                Expanded(child: Text("Butuh bantuan? Hubungkan kedua HP di ruangan yang sama untuk scan QR lebih cepat.", style: TextStyle(color: Color(0xFF8E9099), fontSize: 11))),
              ]),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
