import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Nút đăng nhập Google tuỳ chỉnh (Android / iOS).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.width = double.infinity,
    this.height = 54,
  });

  final Future<void> Function() onPressed;
  final bool busy;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'G',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              busy ? 'Đang đăng nhập...' : 'Đăng nhập Google',
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
