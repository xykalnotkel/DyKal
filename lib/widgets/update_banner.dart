import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/update_service.dart';

/// Banner update in-app: muncul di atas layar utama saat ada rilis baru
/// di GitHub. Menampilkan changelog singkat + tombol download berprogres.
/// Download berjalan di background (tetap lanjut walau banner ditutup),
/// dan installer Android otomatis terbuka setelah selesai.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // Cek update begitu layar utama siap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService.instance,
      builder: (context, _) {
        final svc = UpdateService.instance;
        final info = svc.availableUpdate;
        if (info == null || _dismissed || svc.isChecking) {
          return const SizedBox.shrink();
        }
        // REVISI OWNER: banner dikecilkan & dipindah ke BAWAH (melayang tepat
        // di atas bottom nav), bukan lagi banner besar di atas layar.
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              // 96dp: tinggi bottom nav + margin napas — banner melayang di atasnya.
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDetail(context),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: DyKalTheme.dykalGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: svc.isDownloading
                        ? Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: svc.downloadProgress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(svc.downloadProgress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Update v${info.versionName} tersedia',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _changelogPreview(info.releaseNotes),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: DyKalTheme.primary,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                onPressed: () => UpdateService.instance.downloadAndInstall(),
                                child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                              if (!info.isForce)
                                GestureDetector(
                                  onTap: () => setState(() => _dismissed = true),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.close, color: Colors.white70, size: 18),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _changelogPreview(String notes) {
    final clean = notes
        .replaceAll(RegExp(r'^#{1,6}\s*.*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.isEmpty ? 'Pembaruan stabilitas dan fitur baru' : clean;
  }

  /// Dialog detail: changelog lengkap + tombol download berprogres.
  void _showDetail(BuildContext context) {
    final svc = UpdateService.instance;
    final info = svc.availableUpdate;
    if (info == null) return;
    showDialog(
      context: context,
      barrierDismissible: !info.isForce,
      builder: (ctx) => ListenableBuilder(
        listenable: svc,
        builder: (ctx, _) => AlertDialog(
          title: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/banners/app_update_card.webp',
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.new_releases, color: DyKalTheme.primary),
                  SizedBox(width: 8),
                  Text('Ada Update Nih!'),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Versi baru v${info.versionName}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('Changelog:',
                    style: TextStyle(
                        fontSize: 12,
                        color: DyKalTheme.textSecondaryOf(ctx))),
                const SizedBox(height: 6),
                Text(info.releaseNotes.isEmpty
                    ? 'Pembaruan stabilitas dan fitur baru'
                    : info.releaseNotes),
                const SizedBox(height: 16),
                if (svc.isDownloading) ...[
                  LinearProgressIndicator(
                      value: svc.downloadProgress,
                      minHeight: 8,
                      color: DyKalTheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Mengunduh ${(svc.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 12,
                        color: DyKalTheme.textSecondaryOf(ctx)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!info.isForce)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Nanti'),
              ),
            FilledButton.icon(
              onPressed: svc.isDownloading
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      svc.downloadAndInstall();
                    },
              icon: const Icon(Icons.download, size: 18),
              label: Text(svc.isDownloading ? 'Mengunduh...' : 'Download & Install'),
            ),
          ],
        ),
      ),
    );
  }
}
