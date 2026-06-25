import 'package:flutter/material.dart';

/// Màu và hằng số dùng chung cho bàn chơi offline/online.
abstract final class GameTheme {
  static const gold = Color(0xFFFFD54F);
  static const card = Color(0xFF2A0707);

  /// Kích thước chồng bài giữa bàn — responsive, to hơn trên điện thoại.
  static double pileWidthFor(double viewportWidth) =>
      (viewportWidth * 0.22).clamp(78.0, 92.0);
}
