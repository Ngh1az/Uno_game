import 'package:device_preview/device_preview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'online/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.bootstrap();
  // Khoá hướng dọc (portrait).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    DevicePreview(
      // Chỉ bật Device Preview ở chế độ debug; bản release chạy bình thường.
      enabled: !kReleaseMode,
      builder: (context) => const UnoApp(),
    ),
  );
}

class UnoApp extends StatelessWidget {
  const UnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNO',
      debugShowCheckedModeBanner: false,
      // Các dòng dưới giúp Device Preview điều khiển kích thước/locale màn hình.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
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
