import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // FIX #5: deteksi offline real
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'widgets/seamless_scaffold.dart';
import 'widgets/dykal_bottom_nav.dart';
import 'screens/home/home_screen.dart';
import 'screens/album/album_screen.dart';
import 'screens/letter/letter_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/pairing/pairing_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/call/video_call_screen.dart';
import 'screens/call/audio_call_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'services/auth_service.dart';
import 'services/birthday_service.dart';
import 'services/dev_logger.dart';
import 'services/app_logger.dart'; // FIX: auto-record error ke logs
import 'services/fcm_service.dart';
import 'services/theme_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// FIX #1: key navigator global biar aksi notif (accept/decline/tap) bisa navigasi
final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  DevLogger.instance.info('app', 'Starting DyKal...');
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    DevLogger.instance.info('firebase', 'InitializeApp SUCCESS');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    DevLogger.instance.error('firebase', 'InitializeApp FAILED', e);
  }

  // High refresh rate 60/90/120Hz
  try {
    final modes = await FlutterDisplayMode.supported;
    final high = modes.reduce((a, b) => a.refreshRate > b.refreshRate ? a : b);
    await FlutterDisplayMode.setPreferredMode(high);
  } catch (_) {}

  await ThemeController.instance.load();
  await BirthdayService().init();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: DyKalTheme.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  FCMService.navKey = _navKey;
  // FIX: auto-record error ke Android/media/com.dykal.app/logs/app.log (devlog button dihapus)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('flutter_error', details.exception, details.stack);
  };
  runZonedGuarded(() {
    runApp(ProviderScope(child: DyKalApp()));
  }, (e, st) => AppLogger.error('zone_error', e, st));
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
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        ),
        home: AuthGate(),
        routes: {
          '/chat': (_) => ChatScreen(),
          '/videoCall': (_) => VideoCallScreen(),
          '/audioCall': (_) => AudioCallScreen(),
          '/incomingCall': (_) => IncomingCallScreen(),
          '/profile': (_) => ProfileScreen(),
        },
      ),
    );
  }
}

/// Splash kecil
Widget _splash() => Scaffold(
      backgroundColor: DyKalTheme.background,
      body: Center(child: CircularProgressIndicator(color: DyKalTheme.primary)),
    );

/// Gerbang routing otomatis:
/// belum login -> AuthScreen | login tapi belum couple -> PairingScreen | sudah couple -> MainNav
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (context, authSnap) {
        if (authSnap.connectionState != ConnectionState.active) return _splash();
        final user = authSnap.data;
        if (user == null) {
          DevLogger.instance.info('auth', 'No user -> AuthScreen');
          return AuthScreen();
        }
        DevLogger.instance.info('auth', 'User logged in: ${user.uid}');

        // Inisialisasi FCM sekali per login
        FCMService().ensureInit();

        return StreamBuilder<String?>(
          stream: AuthService().coupleIdStream(),
          builder: (context, cSnap) {
            if (cSnap.connectionState != ConnectionState.active) return _splash();
            final cid = cSnap.data;
            if (cid == null) {
              DevLogger.instance.info('auth', 'coupleId null -> PairingScreen');
              return PairingScreen();
            }
            DevLogger.instance.info('auth', 'coupleId: $cid');
            AuthService().coupleId = cid;
            AuthService().refresh();
            // Hanya masuk app kalau pasangan sudah join (members >= 2).
            // Kalau cuma 1 (creator belum di-join) -> tetap di PairingScreen nunjukin kode.
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('couples/$cid').snapshots(),
              builder: (context, cs) {
                if (!cs.hasData) return _splash();
                final d = cs.data!.data() as Map<String, dynamic>?;
                final members = List<String>.from(d?['members'] ?? []);
                DevLogger.instance.info('auth', 'couple members: ${members.length}');
                return members.length >= 2 ? MainNav() : PairingScreen();
              },
            );
          },
        );
      },
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // FIX #5: lifecycle app
    AuthService().refresh();
    _setPresenceOnline(true);
    _connSub = Connectivity().onConnectivityChanged.listen((res) {
      final offline = res.isEmpty || res.every((e) => e == ConnectivityResult.none);
      _setPresenceOnline(!offline);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenIncomingCalls();
      _listenDelivered();
    });
  }

  // FIX #5: offline = app keluar/data mati ; online = app jalan & ada koneksi
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
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      _setPresenceOnline(false); // keluar app -> offline + lastSeen
    }
  }

  void _listenDelivered() {
    final coupleId = AuthService().coupleId;
    final myId = AuthService().myId;
    if (coupleId == null || coupleId.isEmpty || myId.isEmpty) return;
    FirebaseFirestore.instance.collection('chats/$coupleId/messages').snapshots().listen((qs) {
      for (final d in qs.docs) {
        final m = d.data() as Map<String, dynamic>;
        if (m['fromId'] != myId && m['status'] == 'sent') d.reference.update({'status': 'delivered'});
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
      if (data == null) { handled = false; return; }
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [HomeScreen(), AlbumScreen(), LetterScreen(), ProfileScreen()];
    return SeamlessScaffold(
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(index: idx, children: pages),
      ),
      bottomNavigationBar: DyKalBottomNav(
        currentIndex: idx,
        onTap: (i) => setState(() => idx = i),
      ),
    );
  }
}
