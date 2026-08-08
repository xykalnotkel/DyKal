import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
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
import 'services/fcm_service.dart';
import 'services/theme_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

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

  runApp(ProviderScope(child: DyKalApp()));
}

class DyKalApp extends StatelessWidget {
  const DyKalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
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
        if (user == null) return AuthScreen();

        // Inisialisasi FCM sekali per login
        FCMService().ensureInit();

        return StreamBuilder<String?>(
          stream: AuthService().coupleIdStream(),
          builder: (context, cSnap) {
            if (cSnap.connectionState != ConnectionState.active) return _splash();
            final cid = cSnap.data;
            if (cid == null) return PairingScreen(); // belum punya couple
            AuthService().coupleId = cid; // pastikan ter-cache untuk semua screen
            AuthService().refresh();
            // Hanya masuk app kalau pasangan sudah join (members >= 2).
            // Kalau cuma 1 (creator belum di-join) -> tetap di PairingScreen nunjukin kode.
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.doc('couples/$cid').snapshots(),
              builder: (context, cs) {
                if (!cs.hasData) return _splash();
                final d = cs.data!.data() as Map<String, dynamic>?;
                final members = List<String>.from(d?['members'] ?? []);
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

class _MainNavState extends State<MainNav> {
  int idx = 0;
  StreamSubscription? _callSub;

  @override
  void initState() {
    super.initState();
    AuthService().refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenIncomingCalls());
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
    _callSub?.cancel();
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
