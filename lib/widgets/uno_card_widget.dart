import 'package:flutter/material.dart';

import '../models/uno_card.dart';

/// Màu hiển thị tương ứng với màu lá UNO.
Color unoColor(CardColor color) {
  switch (color) {
    case CardColor.red:
      return const Color(0xFFD32F2F);
    case CardColor.yellow:
      return const Color(0xFFF9A825);
    case CardColor.green:
      return const Color(0xFF388E3C);
    case CardColor.blue:
      return const Color(0xFF1565C0);
    case CardColor.wild:
      return const Color(0xFF212121);
  }
}

/// Tên tiếng Việt của màu (để hiển thị).
String unoColorName(CardColor color) {
  switch (color) {
    case CardColor.red:
      return 'Đỏ';
    case CardColor.yellow:
      return 'Vàng';
    case CardColor.green:
      return 'Xanh lá';
    case CardColor.blue:
      return 'Xanh dương';
    case CardColor.wild:
      return 'Đổi màu';
  }
}

/// Hiển thị một lá bài UNO bằng ảnh trong assets.
///
/// Nếu ảnh chưa có (ví dụ blue_2/blue_3 còn thiếu), tự vẽ một placeholder
/// dựa trên màu và nhãn lá để app không bị vỡ giao diện.
class UnoCardWidget extends StatelessWidget {
  final UnoCard card;
  final double width;
  final VoidCallback? onTap;

  /// Tỉ lệ chuẩn của lá bài UNO (cao / rộng).
  static const double aspectRatio = 1.4;

  const UnoCardWidget({
    super.key,
    required this.card,
    this.width = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * aspectRatio;
    final radius = BorderRadius.circular(width * 0.12);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            card.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _Placeholder(card: card),
          ),
        ),
      ),
    );
  }
}

/// Placeholder vẽ tay khi thiếu ảnh.
class _Placeholder extends StatelessWidget {
  final UnoCard card;
  const _Placeholder({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: unoColor(card.color),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        child: Text(
          card.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Mặt sau lá bài (dùng cho bài úp của đối thủ / draw pile).
class UnoCardBack extends StatelessWidget {
  final double width;
  const UnoCardBack({super.key, this.width = 80});

  @override
  Widget build(BuildContext context) {
    final height = width * UnoCardWidget.aspectRatio;
    final radius = BorderRadius.circular(width * 0.12);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white, width: width * 0.04),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
        ),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: -0.4,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'UNO',
              style: TextStyle(
                color: const Color(0xFFFFC107),
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
