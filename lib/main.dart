import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'widgets/seamless_scaffold.dart';
import 'widgets/dykal_bottom_nav.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/album/album_screen.dart';
import 'screens/letter/letter_screen.dart';
import 'screens/call/audio_call_screen.dart';
import 'screens/call/video_call_screen.dart';
import 'services/birthday_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Support High Refresh Rate 60/90/120Hz
  try {
    await FlutterDisplayMode.setHighRefreshRate();
    final modes = await FlutterDisplayMode.supported;
    final active = await FlutterDisplayMode.active;
    // Pilih mode dengan refreshRate tertinggi
    final highMode = modes.reduce((a, b) => a.refreshRate > b.refreshRate ? a : b);
    await FlutterDisplayMode.setPreferredMode(highMode);
  } catch (_) {}

  // Firebase init (tanpa Storage, jadi Spark free no CC tetap jalan)
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // generate via flutterfire configure
  );

  await BirthdayService().init();

  // Status bar seamless - transparan nyatu
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
    return MaterialApp(
      title: 'DyKal',
      debugShowCheckedModeBanner: false,
      theme: DyKalTheme.lightTheme,
      // Support DPI: MediaQuery auto handle, kita pakai Responsive scaling
      builder: (context, child) {
        // Pastikan text tidak pecah di No DPI / high DPI
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      home: MainNav(),
      routes: {
        '/audioCall': (_) => AudioCallScreen(),
        '/videoCall': (_) => VideoCallScreen(),
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
  final pages = [HomeScreen(), ChatScreen(), AlbumScreen(), LetterScreen()];

  @override
  Widget build(BuildContext context) {
    return SeamlessScaffold(
      // SEAMLESS: extendBody true + TopBar background sama dengan body = tanpa garis pemisah
      extendBody: true,
      body: SafeArea(
        // Hapus top padding untuk seamless, tapi bottom tetap untuk nav
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
