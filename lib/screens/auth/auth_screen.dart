import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final auth = AuthService();
      if (isLogin) {
        await auth.login(email: _email.text.trim(), password: _pass.text.trim());
      } else {
        await auth.register(
          email: _email.text.trim(),
          password: _pass.text.trim(),
          displayName: _name.text.trim(),
        );
      }
      // AuthGate akan otomatis route via authState
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_humanError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _humanError(String e) {
    if (e.contains('invalid-credential') || e.contains('user-not-found') || e.contains('wrong-password')) {
      return 'Email atau password salah';
    }
    if (e.contains('email-already-in-use')) return 'Email sudah terdaftar, silakan login';
    if (e.contains('invalid-email')) return 'Format email tidak valid';
    if (e.contains('weak-password')) return 'Password terlalu lemah (min 6 karakter)';
    if (e.contains('network')) return 'Cek koneksi internet kamu';
    return e.replaceFirst('Exception: ', '').replaceFirst('[firebase_auth/', '');
  }

  @override
  void dispose() {
    _email.dispose(); _pass.dispose(); _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DyKalTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                Text("DyKal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DyKalTheme.textDark)),
                const SizedBox(height: 4),
                Text(isLogin ? "Masuk untuk lanjut" : "Buat akun baru", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 14)),
                const SizedBox(height: 28),

                // Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderSoft)),
                  child: Row(children: [
                    Expanded(child: _toggle(true, "Masuk")),
                    Expanded(child: _toggle(false, "Daftar")),
                  ]),
                ),
                const SizedBox(height: 20),

                if (!isLogin) ...[
                  _field(_name, "Nama Panggilan", Icons.person, false),
                  const SizedBox(height: 12),
                ],
                _field(_email, "Email", Icons.email, false, validator: (v) => (v != null && v.contains('@')) ? null : 'Email tidak valid'),
                const SizedBox(height: 12),
                _field(_pass, "Password", Icons.lock, true, validator: (v) => (v != null && v.length >= 6) ? null : 'Min 6 karakter'),
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isLogin ? "Masuk" : "Daftar"),
                  ),
                ),
                const SizedBox(height: 16),
                Text("Dengan masuk, kamu setuju DyKal hanya untuk kamu & dia 💌",
                    textAlign: TextAlign.center, style: TextStyle(color: DyKalTheme.textGrey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(bool login, String label) {
    final active = isLogin == login;
    return GestureDetector(
      onTap: () => setState(() => isLogin = login),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? DyKalTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? Colors.white : DyKalTheme.textGrey, fontSize: 13)),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, bool obscure, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: DyKalTheme.textGrey),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
