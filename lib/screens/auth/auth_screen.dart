import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/gallery_picker.dart';

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
  File? _photo;
  bool _showPass = false;

  Future<void> _pickPhoto() async {
    final file = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => const GalleryPickerScreen(allowVideo: false)));
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final auth = AuthService();
      if (isLogin) {
        await auth.login(email: _email.text.trim(), password: _pass.text.trim());
      } else {
        String? photoUrl;
        if (_photo != null) {
          photoUrl = await CloudinaryService().uploadAvatar(_photo!);
        }
        await auth.register(
          email: _email.text.trim(),
          password: _pass.text.trim(),
          displayName: _name.text.trim(),
          photoUrl: photoUrl,
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
                Image.asset(
                  'assets/logo/dykal_logo_hd.png',
                  width: 96,
                  height: 96,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(gradient: DyKalTheme.dykalGradient, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 16),
                Text("DyKal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DyKalTheme.textDark)),
                const SizedBox(height: 4),
                Text(isLogin ? "Masuk untuk lanjut" : "Buat akun baru", style: TextStyle(color: DyKalTheme.textGrey, fontSize: 14)),
                const SizedBox(height: 28),

                // Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: DyKalTheme.cardOf(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: DyKalTheme.borderOf(context))),
                  child: Row(children: [
                    Expanded(child: _toggle(true, "Masuk")),
                    Expanded(child: _toggle(false, "Daftar")),
                  ]),
                ),
                const SizedBox(height: 20),

                if (!isLogin) ...[
                  _avatarPicker(),
                  const SizedBox(height: 16),
                  _field(_name, "Nama Panggilan", Icons.person, false, validator: (v) => (v != null && v.trim().length >= 2 && v.trim().length <= 20) ? null : "Nama 2-20 karakter"),
                  const SizedBox(height: 12),
                ],
                _field(_email, "Email", Icons.email, false, validator: (v) { final e = (v ?? '').trim(); final a = e.indexOf('@'); return (a > 0 && e.indexOf('.', a) > a) ? null : 'Email tidak valid'; }),
                const SizedBox(height: 12),
                _passwordField(),
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

  Widget _avatarPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 96, height: 96,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Stack(alignment: Alignment.center, children: [
          _photo != null
              ? ClipOval(child: Image.file(_photo!, width: 92, height: 92, fit: BoxFit.cover))
              : Container(
                  width: 92, height: 92,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: DyKalTheme.primary.withOpacity(0.12)),
                  child: Icon(Icons.person, size: 46, color: DyKalTheme.primary),
                ),
          Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: DyKalTheme.primary, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16))),
        ]),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _pass,
      obscureText: !_showPass,
      validator: (v) => (v != null && v.length >= 6) ? null : 'Min 6 karakter',
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: Icon(Icons.lock, color: DyKalTheme.textGrey),
        suffixIcon: IconButton(
          icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: DyKalTheme.textGrey),
          onPressed: () => setState(() => _showPass = !_showPass),
        ),
        filled: true, fillColor: DyKalTheme.cardOf(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
        filled: true, fillColor: DyKalTheme.cardOf(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
