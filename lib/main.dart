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
import 'widgets/update_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

/// Status inisialisasi Firebase — dibaca AuthGate agar tidak menggantung.
enum AppInitStatus { pending, ready, failed }
AppInitStatus appInitStatus = AppInitStatus.pending;

Future<void> main() async {
  FlutterForegroundTask.initCommunicationPort();
  DevLogger.instance.info('app', 'Starting DyKal...');
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi yang TIDAK butuh Firebase — jalan di background,
  // tidak memblokir runApp (splash langsung tampil).
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
  try { await ThemeController.instance.load(); } catch (_) {}
  try { await BirthdayService().init().timeout(const Duration(seconds: 5)); } catch (_) {}
}

/// Inisialisasi Firebase di background. Status disimpan di [appInitStatus]
/// dan dibaca oleh AuthGate (spinner tidak lagi menggantung selamanya).
Future<void> _initFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      appInitStatus = AppInitStatus.ready;
      return;
    }
    await Firebase.initializeApp().timeout(const Duration(seconds: 20));
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    appInitStatus = AppInitStatus.ready;
    DevLogger.instance.info('firebase', 'InitializeApp SUCCESS');
  } catch (e) {
    appInitStatus = AppInitStatus.failed;
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
        theme: DyKalTheme.lightTheme,
        darkTheme: DyKalTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
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

Widget _splash() => const Scaffold(
      body: Center(child: CircularProgressIndicator(color: DyKalTheme.primary)),
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
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    // Kalau Firebase belum siap dalam 20 detik, tampilkan layar peringatan
    // + tombol Coba Lagi — bukan spinner yang menggantung selamanya.
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() => appInitStatus = AppInitStatus.pending);
    unawaited(_initFirebase());
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final timedOut = _timeout?.isActive == false;
    if (appInitStatus == AppInitStatus.failed ||
        (appInitStatus == AppInitStatus.pending && timedOut)) {
      return _InitErrorScreen(onRetry: _retry);
    }
    if (appInitStatus != AppInitStatus.ready) {
      return _splash();
    }
    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (context, authSnap) {
        if (authSnap.connectionState != ConnectionState.active) return _splash();
        final user = authSnap.data;
        if (user == null) {
          DevLogger.instance.info('auth', 'No user -> AuthScreen');
          return const AuthScreen();
        }
        DevLogger.instance.info('auth', 'User logged in: ${user.uid}');

        FCMService().ensureInit();

        return StreamBuilder<String?>(
          stream: AuthService().coupleIdStream(),
          builder: (context, cSnap) {
            if (cSnap.connectionState != ConnectionState.active) return _splash();
            final cid = cSnap.data;
            if (cid == null) {
              DevLogger.instance.info('auth', 'coupleId null -> PairingScreen');
              return const PairingScreen();
            }
            DevLogger.instance.info('auth', 'coupleId: $cid');
            AuthService().coupleId = cid;
            AuthService().refresh();

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('couples/$cid').snapshots(),
              builder: (context, cs) {
                if (!cs.hasData) return _splash();
                final d = cs.data!.data() as Map<String, dynamic>?;
                final members = List<String>.from(d?['members'] ?? []);
                DevLogger.instance.info('auth', 'couple members: ${members.length}');
                return members.length >= 2 ? const MainNav() : const PairingScreen();
              },
            );
          },
        );
      },
    );
  }
}

/// Layar peringatan saat Firebase tidak bisa dijangkau — dengan tombol coba lagi.
class _InitErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _InitErrorScreen({required this.onRetry});

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
                'Gagal menghubungi server',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'DyKal tidak bisa menghubungi Firebase. Pastikan internet aktif, lalu coba lagi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 13),
              ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService().refresh();
    _setPresenceOnline(true);
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      final offline = res.isEmpty || res.every((e) => e == ConnectivityResult.none);
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
    final uid = AuthService().myId;
    if (uid.isEmpty) return;
    FirebaseFirestore.instance.doc('presence/$uid').set({
      'isOnline': online,
      if (!online) 'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setPresenceOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _setPresenceOnline(false);
    }
  }

  void _listenDelivered() {
    final coupleId = AuthService().coupleId;
    final myId = AuthService().myId;
    if (coupleId == null || coupleId.isEmpty || myId.isEmpty) return;

    // Filter terarah hemat resource Firestore
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
      if (callerId != myId && status == 'ringing' && !handled) {
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
