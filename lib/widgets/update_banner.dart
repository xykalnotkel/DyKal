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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showDetail(context),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: AssetImage('assets/banners/app_update_banner.webp'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.rocket_launch,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ADA UPDATE NIH!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    fontFamily: isDark ? null : 'Poppins',
                                  ),
                                ),
                              ),
                              if (!info.isForce)
                                GestureDetector(
                                  onTap: () => setState(() => _dismissed = true),
                                  child: const Icon(Icons.close,
                                      color: Colors.white70, size: 20),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Versi baru v${info.versionName} tersedia untuk kamu',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _changelogPreview(info.releaseNotes),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (svc.isDownloading)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: svc.downloadProgress,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mengunduh ${(svc.downloadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: DyKalTheme.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () =>
                                      UpdateService.instance.downloadAndInstall(),
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('Update Sekarang',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => _showDetail(context),
                                  child: const Text('Lihat changelog',
                                      style: TextStyle(
                                          color: Colors.white,
                                          decoration:
                                              TextDecoration.underline)),
                                ),
                              ],
                            ),
                        ],
                      ),
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
          title: Row(
            children: [
              const Icon(Icons.new_releases, color: DyKalTheme.primary),
              const SizedBox(width: 8),
              const Text('Ada Update Nih!'),
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
