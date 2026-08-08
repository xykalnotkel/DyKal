import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool isCreating = true;
  String? myCode;
  final _codeController = TextEditingController();
  bool loading = false;

  Future<void> _createCode() async {
    setState(() => loading = true);
    try {
      final code = await AuthService().createCoupleAndInviteCode();
      setState(() { myCode = code; loading = false; });
    } catch (e) {
      setState(() => loading = false);
      _toast('Gagal membuat kode: $e');
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.length < 6) { _toast('Masukkan kode yang valid'); return; }
    setState(() => loading = true);
    try {
      await AuthService().joinWithCode(code);
      // AuthGate auto-route ke MainNav karena coupleId ter-set
    } catch (e) {
      setState(() => loading = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.favorite, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text("DyKal Pairing", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            Image.asset('assets/illustrations/webp/pairing.webp', width: 280, height: 150, fit: BoxFit.contain, errorBuilder: (_, __, ___) => SizedBox(height: 150)),
            const SizedBox(height: 8),
            Text(
              isCreating ? "Hubungkan dengan Pasangan" : "Masukkan Kode Pasangan",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isCreating
                  ? "Bagikan kode ini ke Ayang. Akun kalian akan terhubung, hanya berdua."
                  : "Masukkan kode dari Ayang untuk terhubung.",
              style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderSoft)),
              child: Row(children: [
                Expanded(child: _toggle(true, Icons.share, "Buat Kode")),
                Expanded(child: _toggle(false, Icons.login, "Masuk Kode")),
              ]),
            ),
            const SizedBox(height: 20),

            if (isCreating) _createPanel() else _joinPanel(),

            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.info, size: 14, color: DyKalTheme.textGrey),
              const SizedBox(width: 6),
              Expanded(child: Text("Kode berlaku 24 jam & sekali pakai. Privasi hanya untuk kalian berdua.",
                  style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _toggle(bool create, IconData icon, String label) {
    final active = isCreating == create;
    return GestureDetector(
      onTap: () => setState(() { isCreating = create; myCode = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? Colors.white : DyKalTheme.textGrey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: active ? Colors.white : DyKalTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _createPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.qr_code_2, color: DyKalTheme.primary, size: 18),
          const SizedBox(width: 8),
          const Text("Kode Pairing Kamu", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (myCode != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: DyKalTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [Icon(Icons.history, size: 12, color: DyKalTheme.success), const SizedBox(width: 4), Text("Aktif 24 jam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DyKalTheme.success))]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.primary.withOpacity(0.2), width: 1.5)),
          child: Text(
            myCode ?? (loading ? "Membuat..." : "Tekan tombol di bawah"),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 4, color: DyKalTheme.textDark),
          ),
        ),
        const SizedBox(height: 14),
        if (myCode == null)
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: loading ? null : _createCode,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text("Buat Kode Sekarang"),
          ))
        else
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: myCode!)); _toast("Kode disalin"); },
              icon: const Icon(Icons.content_copy, size: 16), label: const Text("Salin"),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: myCode!)); _toast("Bagikan ke Ayang"); },
              icon: const Icon(Icons.share, size: 16), label: const Text("Bagikan"),
            )),
          ]),
        if (myCode != null) ...[
          const SizedBox(height: 12),
          Text("Tunggu Ayang masukin kode ini... layar akan pindah otomatis saat terhubung.",
              textAlign: TextAlign.center, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _joinPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        Image.asset('assets/illustrations/webp/pairing_code.webp', width: 130, height: 70, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 70)),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 6, fontSize: 18),
          decoration: InputDecoration(
            hintText: "DYKAL-XXXX",
            hintStyle: TextStyle(letterSpacing: 4, color: DyKalTheme.textGrey.withOpacity(0.5)),
            filled: true, fillColor: DyKalTheme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: loading ? null : _join,
          icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.link, size: 16),
          label: const Text("Hubungkan Sekarang"),
        )),
      ]),
    );
  }
}
