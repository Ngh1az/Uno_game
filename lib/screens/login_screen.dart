import 'package:flutter/material.dart';

import '../online/auth_service.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/uno_circle_button.dart';

/// Màn đăng nhập: nền full + nút đặt trực tiếp lên ảnh (không panel).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập thất bại');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF2A0707)),
          Image.asset(
            'assets/images/background/loginscreen2.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          // Gradient nhẹ giúp nút đọc rõ, không tạo hộp riêng.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.62),
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x990D0202)],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 12,
                  child: UnoCircleButton(
                    icon: Icons.settings,
                    label: '',
                    showLabel: false,
                    size: 50,
                    onTap: () => SettingsSheet.show(context),
                  ),
                ),
                // Nút nằm trong vùng đỏ phía dưới ảnh nền (~68% từ trên).
                Align(
                  alignment: const Alignment(0, 0.68),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          GoogleSignInButton(
                            width: double.infinity,
                            busy: _busy,
                            onPressed: () => _run(_auth.signInWithGoogle),
                          ),
                          const SizedBox(height: 14),
                          _loginButton(
                            label: 'Chơi ngay',
                            icon: const Icon(Icons.person, size: 22),
                            bg: const Color(0xFFFFC400),
                            fg: Colors.black87,
                            onTap: _auth.signInAsGuest,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFFAB40),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginButton({
    required String label,
    required Widget icon,
    required Color bg,
    required Color fg,
    required Future<void> Function() onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        onPressed: _busy ? null : () => _run(onTap),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

