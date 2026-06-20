import 'package:flutter/material.dart';

/// Hỏi xác nhận trước khi đăng xuất. Trả về `true` nếu người dùng đồng ý.
Future<bool> confirmSignOut(BuildContext context) async {
  const card = Color(0xFF2A0707);
  const gold = Color(0xFFFFC400);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x44FFD54F)),
      ),
      title: const Text(
        'Đăng xuất?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'Bạn có chắc muốn đăng xuất không?',
        style: TextStyle(color: Colors.white70, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Đăng xuất',
            style: TextStyle(color: gold, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
