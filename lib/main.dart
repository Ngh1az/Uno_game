import 'debug/device_preview_binding.dart'
    if (dart.library.js_interop) 'debug/device_preview_binding_web.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'firebase_options.dart';
import 'navigation/app_navigator.dart';
import 'friends/presence_service.dart';
import 'online/auth_service.dart';
import 'online/waiting_room_session.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/room_invite_listener.dart';
import 'widgets/waiting_room_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.bootstrap();
  await AppSettings.instance.load();
  // Khoá hướng dọc (portrait).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runAppWithPreview(const UnoApp());
}

class UnoApp extends StatefulWidget {
  const UnoApp({super.key});

  @override
  State<UnoApp> createState() => _UnoAppState();
}

class _UnoAppState extends State<UnoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = AuthService();
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        PresenceService.instance.goOffline();
      case AppLifecycleState.detached:
        PresenceService.instance.goOffline();
        unawaited(WaitingRoomSession.instance.leave().catchError((_) {}));
      case AppLifecycleState.resumed:
        PresenceService.instance.start(uid);
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'UNO',
      debugShowCheckedModeBanner: false,
      locale: devicePreviewLocale(context),
      builder: (context, child) {
        final app = RoomInviteListener(
          navigatorKey: rootNavigatorKey,
          child: WaitingRoomOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
        return devicePreviewBuilder(context, app);
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Quyết định màn hình: đã đăng nhập (Google hoặc khách) → Home, chưa → Login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF2A0707),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC400)),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
