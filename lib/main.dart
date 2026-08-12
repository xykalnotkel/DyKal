import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'config/theme.dart';
import 'widgets/seamless_scaffold.dart';
import 'widgets/dykal_bottom_nav.dart';
import 'screens/home/home_screen.dart';
import 'screens/album/album_screen.dart';
import 'screens/letter/letter_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/pairing/pairing_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/call/video_call_screen.dart';
import 'screens/call/audio_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'services/auth_service.dart';
import 'services/birthday_service.dart';
import 'services/dev_logger.dart';
import 'services/app_logger.dart';
import 'services/fcm_service.dart';
import 'services/floating_service.dart';
import 'services/theme_controller.dart';
import 'services/bubble_style.dart';
import 'services/wallpaper_settings.dart';
import 'services/update_service.dart';
import 'services/presence_service.dart';
import 'services/font_scale.dart';
import 'widgets/update_banner.dart';
import 'widgets/return_to_call_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // BATCH G (spek v2 #4): payload data-only dirender sebagai notif kaya
  // (avatar + aksi) oleh FCMService — bukan lagi no-op.
  await FCMService.firebaseMessagingBackgroundHandler(message);
}

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

/// Status inisialisasi Firebase — dibaca AuthGate agar tidak menggantung.
enum AppInitStatus { pending, ready, failed }
AppInitStatus appInitStatus = AppInitStatus.pending;

/// Pesan error terakhir saat inisialisasi Firebase gagal (untuk layar error).
String? appInitError;

/// Tahap boot saat ini (untuk layar error) — global karena di-set dari _initFirebase.
String bootStage = 'Memulai...';

Future<void> main() async {
  FlutterForegroundTask.initCommunicationPort();
  DevLogger.instance.info('app', 'Starting DyKal...');
  WidgetsFlutterBinding.ensureInitialized();

  // BATCH H (keluhan owner: tema "flash" & terasa tergantung server):
  // Theme/BubbleStyle/WallpaperSettings itu 100% LOKAL (SharedPreferences) —
  // muat SEBELUM runApp agar frame pertama langsung benar (tanpa flash tema
  // default) dan bekerja penuh walau HP offline total.
  try { await ThemeController.instance.load(); } catch (_) {}
  try { await BubbleStyle.instance.load(); } catch (_) {}
  try { await WallpaperSettings.instance.load(); } catch (_) {}
  try { await FontScale.load(); } catch (_) {}
  try { await AuthService().loadCache(); } catch (_) {}

  // Sisanya (birthday, callback update) non-kritis — background.
  unawaited(_initNonFirebase());

  // Firebase — background juga; hasilnya dibaca AuthGate via appInitStatus.
  unawaited(_initFirebase());

  final darkBars = ThemeController.instance.mode == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: darkBars ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: darkBars ? DyKalTheme.backgroundDark : DyKalTheme.background,
    systemNavigationBarIconBrightness: darkBars ? Brightness.light : Brightness.dark,
  ));

  FCMService.navKey = _navKey;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('flutter_error', details.exception, details.stack);
  };

  runZonedGuarded(() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'screen_share',
        channelName: 'DyKal Screen Share',
        channelDescription: 'Saat berbagi layar',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing()),
    );
    runApp(const DyKalApp());
  }, (e, st) => AppLogger.error('zone_error', e, st));
}

/// Inisialisasi non-Firebase — masing-masing diberi batas waktu agar
/// tidak ada satu pun yang bisa menggantung startup aplikasi.
Future<void> _initNonFirebase() async {
  // Unlock high refresh rate 90/120Hz (non-kritis; timeout 3 detik)
  try {
    final modes = await FlutterDisplayMode.supported.timeout(const Duration(seconds: 3));
    final high = modes.reduce((a, b) => a.refreshRate > b.refreshRate ? a : b);
    await FlutterDisplayMode.setPreferredMode(high);
  } catch (_) {}
  // Aksi "Unduh Sekarang" dari notif update (diputus via callback agar
  // fcm_service tidak import update_service -> siklus).
  FCMService.onUpdateDownload = () => UpdateService.instance.downloadAndInstall();
  try { await BirthdayService().init().timeout(const Duration(seconds: 5)); } catch (_) {}
}

/// Inisialisasi Firebase di background. Status disimpan di [appInitStatus]
/// dan dibaca oleh AuthGate (spinner tidak lagi menggantung selamanya).
Future<void> _initFirebase() async {
  try {
    bootStage = 'Menghubungi Firebase...';
    if (Firebase.apps.isNotEmpty) {
      appInitStatus = AppInitStatus.ready;
      bootStage = 'Firebase siap';
      return;
    }
    await Firebase.initializeApp().timeout(const Duration(seconds: 15));
    // OFFLINE-FIRST ala WA (permintaan owner): persistence sebenarnya sudah
    // default ON di Android, tapi kita kunci eksplisit + cache tak terbatas
    // agar riwayat chat SELALU bisa dibaca tanpa internet. Harus diset
    // SEBELUM instance Firestore dipakai pertama kali.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    appInitStatus = AppInitStatus.ready;
    bootStage = 'Firebase siap';
    DevLogger.instance.info('firebase', 'InitializeApp SUCCESS');
  } catch (e) {
    appInitStatus = AppInitStatus.failed;
    appInitError = '$e';
    bootStage = 'Inisialisasi Firebase gagal';
    DevLogger.instance.error('firebase', 'InitializeApp FAILED', e);
  }
}

class DyKalApp extends StatelessWidget {
  const DyKalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navKey,
        title: 'DyKal',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeController.instance.mode,
        // Tema dibangun dari GAYA aktif (rounded/ios/sharp) — lihat theme.dart.
        // ListenableBuilder di atas memastikan pergantian gaya langsung menempel.
        theme: DyKalTheme.lightTheme(
          cardRadius: ThemeController.instance.cardRadius,
          buttonRadius: ThemeController.instance.buttonRadius,
        ),
        darkTheme: DyKalTheme.darkTheme(
          cardRadius: ThemeController.instance.cardRadius,
          buttonRadius: ThemeController.instance.buttonRadius,
        ),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: FontScale.value,
          builder: (context, scale, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: const SplashGate(),
        routes: {
          '/chat': (_) => const ChatScreen(),
          '/videoCall': (_) => const VideoCallScreen(),
          '/audioCall': (_) => const AudioCallScreen(),
          '/incomingCall': (_) => const IncomingCallScreen(),
          '/profile': (_) => const ProfileScreen(),
        },
      ),
    );
  }
}

/// Mini-boot bermerek (menggantikan spinner polos "muter-muter"):
/// logo + bar ramping + tahap proses, konsisten dengan SplashScreen utama.
Widget _splash() => Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DyKalTheme.background, Color(0xFFFFE9EE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo/dykal_logo_transparent.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.favorite, size: 64, color: DyKalTheme.primary)),
              const SizedBox(height: 14),
              const Text('DyKal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              const SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  color: DyKalTheme.primary,
                  backgroundColor: DyKalTheme.borderSoft,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 12),
              // BATCH H (owner): tanpa teks teknis "Menghubungi Firebase..." —
              // splash bermerek saja, detail tahap hanya relevan di layar error.
              const Text('Ruang kecil kalian berdua',
                  style: TextStyle(fontSize: 12, color: DyKalTheme.textGrey)),
            ],
          ),
        ),
      ),
    );

/// Menampilkan splash screen beranimasi (logo + love) lalu masuk ke AuthGate.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return SplashScreen(onComplete: () => setState(() => _done = true));
    }
    return const AuthGate();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Timer? _bootTimer;
  bool _bootFailed = false;
  bool _reachedContent = false;

  // Diagnostik: error terakhir — ditampilkan di layar error
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _startBootTimer();
  }

  /// Jika dalam 20 detik aplikasi belum sampai ke layar konten (auth/pairing/
  /// main), tampilkan layar "Gagal menghubungi server" + Coba Lagi —
  /// TIDAK ada spinner yang menggantung selamanya.
  void _startBootTimer() {
    _bootFailed = false;
    _reachedContent = false;
    _bootTimer?.cancel();
    _bootTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_reachedContent) setState(() => _bootFailed = true);
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      appInitStatus = AppInitStatus.pending;
      _bootFailed = false;
      bootStage = 'Memulai...';
      _lastError = null;
    });
    unawaited(_initFirebase());
    _startBootTimer();
  }

  bool get _showError => _bootFailed || appInitStatus == AppInitStatus.failed;

  @override
  Widget build(BuildContext context) {
    if (_showError) {
      final detail = _lastError ?? appInitError;
      final stage = _lastError == null && appInitStatus == AppInitStatus.failed
          ? 'Inisialisasi Firebase gagal'
          : bootStage;
      return _InitErrorScreen(onRetry: _retry, detail: detail, stage: stage);
    }
    if (appInitStatus != AppInitStatus.ready) return _splash();

    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (context, authSnap) {
        // Stream error (mis. Firestore ditolak / jaringan) -> layar error, bukan spinner
        if (authSnap.hasError || _bootFailed) {
          if (authSnap.hasError) _lastError = '${authSnap.error}';
          if (_bootFailed && _lastError == null) {
            _lastError = 'Stream auth tidak selesai (jaringan/App Check?)';
          }
          return _InitErrorScreen(onRetry: _retry, detail: _lastError, stage: bootStage);
        }
        if (authSnap.connectionState != ConnectionState.active) {
          bootStage = 'Menunggu status login...';
          return _splash();
        }
        final user = authSnap.data;
        if (user == null) {
          DevLogger.instance.info('auth', 'No user -> AuthScreen');
          _reachedContent = true;
          return const AuthScreen();
        }
        DevLogger.instance.info('auth', 'User logged in: ${user.uid}');

        // Self-heal doc users (nama hilang era bug auth lama) — sekali per sesi
        unawaited(AuthService().ensureUserDoc());

        FCMService().ensureInit();

        return StreamBuilder<String?>(
          stream: AuthService().coupleIdStream(),
          builder: (context, cSnap) {
            if (cSnap.hasError || _bootFailed) {
              if (cSnap.hasError) _lastError = '${cSnap.error}';
              if (_bootFailed && _lastError == null) {
                _lastError = 'Gagal membaca data user (jaringan/App Check/permission rules?)';
              }
              return _InitErrorScreen(onRetry: _retry, detail: _lastError, stage: bootStage);
            }
            // BATCH O (owner): OFFLINE-FIRST ala WA — saat stream masih waiting,
            // jika kita SUDAH punya cache coupleId dari sesi sebelumnya,
            // JANGAN tampilkan spinner "Menunggu data pasangan/couple..."!
            // Langsung lanjut pakai data cache.
            final cid = cSnap.hasData
                ? cSnap.data
                : (cSnap.connectionState == ConnectionState.waiting
                    ? (AuthService().coupleId ?? AuthService().cachedCoupleId)
                    : null);

            if (cid == null && cSnap.connectionState != ConnectionState.active) {
              bootStage = 'Menunggu data pasangan...';
              return _splash();
            }
            if (cid == null) {
              DevLogger.instance.info('auth', 'coupleId null -> PairingScreen');
              _reachedContent = true;
              return const PairingScreen();
            }
            DevLogger.instance.info('auth', 'coupleId: $cid');
            AuthService().coupleId = cid;
            AuthService().refresh();

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('couples/$cid').snapshots(),
              builder: (context, cs) {
                if (cs.hasError || _bootFailed) {
                  if (cs.hasError) _lastError = '${cs.error}';
                  if (_bootFailed && _lastError == null) {
                    _lastError = 'Dokumen couple tidak terbaca (permission rules / App Check?)';
                  }
                  return _InitErrorScreen(onRetry: _retry, detail: _lastError, stage: bootStage);
                }
                if (!cs.hasData) {
                  if (AuthService().isPairedCached) {
                    _reachedContent = true;
                    return const MainNav();
                  }
                  bootStage = 'Menunggu data couple...';
                  return _splash();
                }
                // Self-heal: doc couple tidak ada tapi users.coupleId masih
                // menunjuk ke sana (warisan data setengah jadi) -> bersihkan
                // & anggap belum pairing. Tanpa ini, boot bisa looping error.
                if (!cs.data!.exists) {
                  unawaited(AuthService().clearStaleCouple());
                  DevLogger.instance.info('auth', 'couple doc hilang -> reset & PairingScreen');
                  _reachedContent = true;
                  return const PairingScreen();
                }
                final d = cs.data!.data() as Map<String, dynamic>?;
                final members = List<String>.from(d?['members'] ?? []);
                DevLogger.instance.info('auth', 'couple members: ${members.length}');
                _reachedContent = true;
                return members.length >= 2 ? const MainNav() : const PairingScreen();
              },
            );
          },
        );
      },
    );
  }
}

/// Layar peringatan saat aplikasi tidak bisa lanjut — dengan tombol coba lagi
/// dan detail error (agar penyebabnya terlihat, bukan hitam).
class _InitErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final String? detail;
  final String stage;
  const _InitErrorScreen({required this.onRetry, this.detail, this.stage = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: DyKalTheme.textGrey),
              const SizedBox(height: 16),
              const Text(
                'Gagal Menghubungi Server',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'DyKal tidak bisa lanjut.\n\n'
                'Tahap: $stage',
                textAlign: TextAlign.center,
                style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 13),
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    detail!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tidak ada pesan error detail — koneksi menggantung, kemungkinan ditolak server.\n'
                    'Periksa: (1) App Check di Firebase Console dimatikan, (2) internet aktif, '
                    '(3) akun & data pasangan masih ada.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  int idx = 0;
  StreamSubscription? _callSub;
  StreamSubscription? _connSub;
  StreamSubscription? _deliveredSub;
  String _lastNet = 'none'; // jenis koneksi terakhir (wifi/mobile/none)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService().refresh();
    _setPresenceOnline(true);
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      final offline = res.isEmpty || res.every((e) => e == ConnectivityResult.none);
      String net = 'none';
      if (res.contains(ConnectivityResult.wifi)) {
        net = 'wifi';
      } else if (res.contains(ConnectivityResult.mobile)) {
        net = 'mobile';
      } else if (!offline) {
        net = 'other';
      }
      _lastNet = net;
      _setPresenceOnline(!offline);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenIncomingCalls();
      _listenDelivered();
      _maybeShowFloatingBubble();
    });
  }

  /// Floating bubble otomatis muncul setiap aplikasi dibuka (jika sudah
  /// diaktifkan di Settings dan izin overlay diberikan). Klik bubble = buka chat.
  Future<void> _maybeShowFloatingBubble() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('floating_bubble_enabled') ?? false;
      if (!enabled) return;
      final ok = await FloatingService.hasOverlayPermission();
      if (ok) await FloatingService.showChatBubble();
    } catch (_) {}
  }

  void _setPresenceOnline(bool online) {
    // BATCH I: presence dipegang PresenceService (heartbeat 45 dtk + status
    // jujur). Fungsi lama direute ke sana agar semua lifecycle tetap bekerja.
    final ps = PresenceService.instance;
    if (online) {
      ps.setNet(_lastNet);
      ps.start();
    } else {
      ps.setNet('none');
      unawaited(ps.stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setPresenceOnline(true);
      _openPendingBubbleRoute();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _setPresenceOnline(false);
    }
  }

  /// Menu bubble "Buka Chat" menitipkan rute via shared prefs (native);
  /// konsumsi di sini saat app resume.
  Future<void> _openPendingBubbleRoute() async {
    final route = await FloatingService.consumePendingRoute();
    if (route == 'chat' && mounted) {
      Navigator.of(context).pushNamed('/chat');
    }
  }

  void _listenDelivered() {
    final coupleId = AuthService().coupleId;
    if (coupleId == null || coupleId.isEmpty) return;
    // Start heartbeat sesegera mungkin (status Online akurat per Batch I).
    PresenceService.instance.setNet(_lastNet);
    PresenceService.instance.start();
    // Tandai delivered — termasuk saat app baru dibuka (bukan cuma snapshot).
    unawaited(FCMService.markDeliveredNow(coupleId));

    final myId = AuthService().myId;
    if (myId.isEmpty) return;
    _deliveredSub = FirebaseFirestore.instance
        .collection('chats/$coupleId/messages')
        .where('status', isEqualTo: 'sent')
        .snapshots()
        .listen((qs) {
      for (final d in qs.docs) {
        final m = d.data();
        if (m['fromId'] != myId) {
          d.reference.update({'status': 'delivered'});
        }
      }
    });
  }

  void _listenIncomingCalls() {
    final coupleId = AuthService().coupleId;
    final myId = AuthService().myId;
    if (coupleId == null || coupleId.isEmpty || myId.isEmpty) return;
    bool handled = false;

    _callSub = FirebaseFirestore.instance.doc('calls/$coupleId').snapshots().listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      if (data == null) {
        handled = false;
        return;
      }
      final callerId = data['callerId'] as String?;
      final status = data['status'] as String?;
      if (callerId != myId && status == 'ringing' && !handled && !IncomingCallScreen.isShowing) {
        handled = true;
        final type = (data['type'] as String?) ?? 'video';
        Navigator.of(context).pushNamed('/incomingCall', arguments: type);
      }
      if (status == 'ended') handled = false;
    });
  }

  @override
  void dispose() {
    _setPresenceOnline(false);
    _connSub?.cancel();
    _callSub?.cancel();
    _deliveredSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), AlbumScreen(), LetterScreen(), ProfileScreen()];
    return SeamlessScaffold(
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(index: idx, children: pages),
            const UpdateBanner(),
            // Spek v2 #5B: strip hijau berkedip saat panggilan aktif
            // dikecilkan — ketuk untuk kembali ke panggilan.
            const ReturnToCallBar(),
          ],
        ),
      ),
      bottomNavigationBar: DyKalBottomNav(
        currentIndex: idx,
        onTap: (i) => setState(() => idx = i),
      ),
    );
  }
}
