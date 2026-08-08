import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool isCreating = true;
  String? myCode; // kode hasil "Buat Kode" di sesi ini
  final _codeController = TextEditingController(); // 4 huruf doang (auto DYKAL-)
  bool loading = false;
  final _waitingCoupleId = AuthService().coupleId; // kalau sudah buat couple (1 member) -> mode nunggu

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
    final raw = _codeController.text.trim().toUpperCase();
    if (raw.length < 4) { _toast('Masukkan 4 huruf kode'); return; }
    final fullCode = 'DYKAL-$raw';
    setState(() => loading = true);
    try {
      await AuthService().joinWithCode(fullCode);
      // AuthGate auto-route ke MainNav saat members jadi 2
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
    // Sudah punya couple tapi belum di-join pasangan -> mode nunggu (ambil kode dari couple doc)
    if (_waitingCoupleId != null && myCode == null) {
      return Scaffold(
        backgroundColor: DyKalTheme.background,
        body: SafeArea(child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.doc('couples/$_waitingCoupleId').snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final code = (data?['inviteCode'] as String?) ?? '...';
            return _content(code, waiting: true);
          },
        )),
      );
    }
    // Baru saja bikin kode di sesi ini
    if (myCode != null) return Scaffold(backgroundColor: DyKalTheme.background, body: SafeArea(child: _content(myCode!, waiting: true)));
    // Fresh: create / join
    return Scaffold(backgroundColor: DyKalTheme.background, body: SafeArea(child: _content(null, waiting: false)));
  }

  Widget _content(String? code, {required bool waiting}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.favorite, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text("DyKal Pairing", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (waiting) IconButton(onPressed: () => AuthService().logout(), icon: const Icon(Icons.logout, color: Colors.red)),
        ]),
        const SizedBox(height: 16),
        Image.asset('assets/illustrations/webp/pairing.webp', width: 260, height: 140, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 140)),
        const SizedBox(height: 8),
        Text(waiting ? "Bagikan Kode" : (isCreating ? "Hubungkan Akun" : "Masukkan Kode"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(waiting ? "Bagikan kode ini. Layar pindah otomatis saat ia bergabung." : (isCreating ? "Bikin kode lalu kirim untuk menghubungkan akun kalian." : "Masukkan 4 huruf kodenya."), style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        if (waiting) ...[
          _codeCard(code ?? '...'),
          const SizedBox(height: 16),
          Row(children: [Icon(Icons.hourglass_top, size: 16, color: DyKalTheme.secondary), const SizedBox(width: 8), Expanded(child: Text("Menunggu pasangan bergabung…", style: TextStyle(color: DyKalTheme.secondary, fontSize: 13, fontWeight: FontWeight.w600)))]),
        ] else ...[
          // Toggle
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderSoft)), child: Row(children: [_toggle(true, Icons.share, "Buat Kode"), _toggle(false, Icons.login, "Masuk Kode")])),
          const SizedBox(height: 20),
          if (isCreating) _createPanel() else _joinPanel(),
        ],
      ]),
    );
  }

  Widget _codeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        Row(children: [Icon(Icons.qr_code_2, color: DyKalTheme.primary, size: 18), const SizedBox(width: 8), const Text("Kode Pairing Kamu", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: DyKalTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.history, size: 12, color: DyKalTheme.success), const SizedBox(width: 4), Text("Aktif 24 jam", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DyKalTheme.success))]))]),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16), decoration: BoxDecoration(color: DyKalTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: DyKalTheme.primary.withOpacity(0.2), width: 1.5)), child: Text(code, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: 3, color: Color(0xFFFF6B8A)))),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: code)); _toast("Kode disalin"); }, icon: const Icon(Icons.content_copy, size: 16), label: const Text("Salin"))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: code)); _toast("Kode siap dikirim"); }, icon: const Icon(Icons.share, size: 16), label: const Text("Bagikan")))]),
      ]),
    );
  }

  Widget _toggle(bool create, IconData icon, String label) {
    final active = isCreating == create;
    return Expanded(child: GestureDetector(onTap: () => setState(() => isCreating = create), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: active ? DyKalTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: active ? Colors.white : DyKalTheme.textGrey), const SizedBox(width: 6), Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: active ? Colors.white : DyKalTheme.textGrey))]))));
  }

  Widget _createPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        const Text("Klik tombol di bawah untuk membuat kode pairing unik buat kalian berdua.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF8E9099))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : _createCode, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16), label: const Text("Buat Kode Sekarang"))),
      ]),
    );
  }

  Widget _joinPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DyKalTheme.borderSoft)),
      child: Column(children: [
        const Text("Masukkan 4 huruf kodenya", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        // Auto-prefix DYKAL- + 4 huruf uppercase
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
          textInputAction: TextInputAction.done,
          onChanged: (v) => setState(() {}),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 8, fontSize: 22),
          decoration: InputDecoration(
            counterText: '',
            prefixText: 'DYKAL-',
            prefixStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18, color: DyKalTheme.primary),
            hintText: 'XXXX',
            hintStyle: TextStyle(letterSpacing: 8, color: DyKalTheme.textGrey.withOpacity(0.4)),
            filled: true, fillColor: DyKalTheme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : _join, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.link, size: 16), label: const Text("Hubungkan Sekarang"))),
      ]),
    );
  }
}
