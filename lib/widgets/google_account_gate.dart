import 'package:flutter/material.dart';

import '../online/auth_service.dart';

/// Yêu cầu đăng nhập Google cho tính năng cần tài khoản thật.
Future<bool> requireGoogleAccount(BuildContext context) async {
  if (!AuthService().isGuest) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A0505),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x44FFD54F)),
      ),
      title: const Text(
        'Cần tài khoản Google',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Tính năng này chỉ dùng được khi đăng nhập Google.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Đóng', style: TextStyle(color: Colors.white54)),
        ),
      ],
    ),
  );
  return go == true;
}
