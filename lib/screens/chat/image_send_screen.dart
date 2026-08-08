import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/cloudinary_service.dart';

class ImageSendScreen extends StatefulWidget {
  final File image;
  const ImageSendScreen({super.key, required this.image});

  @override
  State<ImageSendScreen> createState() => _ImageSendScreenState();
}

class _ImageSendScreenState extends State<ImageSendScreen> {
  final _caption = TextEditingController();
  bool viewOnce = false;
  bool sending = false;

  Future<void> _send() async {
    setState(() => sending = true);
    final url = await CloudinaryService().uploadImage(widget.image, folder: viewOnce ? 'dykal/view_once' : 'dykal/chat');
    if (!mounted) return;
    if (url == null) {
      setState(() => sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal upload. Cek preset Cloudinary.')));
      return;
    }
    Navigator.pop(context, {'url': url, 'caption': _caption.text.trim(), 'viewOnce': viewOnce});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kirim Foto'),
        actions: [
          IconButton(
            onPressed: () => setState(() => viewOnce = !viewOnce),
            icon: Icon(viewOnce ? Icons.visibility_off : Icons.visibility, color: viewOnce ? DyKalTheme.primary : Colors.white),
            tooltip: '1x lihat',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: InteractiveViewer(child: Image.file(widget.image, fit: BoxFit.contain))),
          if (viewOnce)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DyKalTheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(Icons.visibility_off, color: DyKalTheme.primary, size: 16), const SizedBox(width: 8), const Expanded(child: Text('Foto sekali lihat — hilang setelah dibuka', style: TextStyle(color: Colors.white, fontSize: 12)))]),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.black,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _caption,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tambahkan pesan...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true, fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: sending ? null : _send,
                child: Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient, shape: BoxShape.circle),
                  child: sending
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
