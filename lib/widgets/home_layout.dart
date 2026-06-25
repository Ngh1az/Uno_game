import 'package:flutter/material.dart';

/// Kích thước dùng chung cho các khối nội dung trên Home.
abstract final class HomeLayout {
  static const largeScreenMinWidth = 600.0;
  static const shortHubMaxHeight = 520.0;
  static const compactHubMaxHeight = 560.0;

  static double padH(BuildContext context) {
    return (MediaQuery.sizeOf(context).width * 0.065).clamp(18.0, 32.0);
  }

  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < largeScreenMinWidth) return width;
    return width.clamp(520.0, 640.0);
  }

  static EdgeInsets contentPadding(BuildContext context) {
    final h = padH(context);
    return EdgeInsets.symmetric(horizontal: h);
  }

  static bool isWideBox(double maxWidth) => maxWidth >= largeScreenMinWidth;

  static bool isShortHub(double maxHeight) => maxHeight < shortHubMaxHeight;

  static bool isCompactHub({
    required double maxWidth,
    required double maxHeight,
  }) =>
      maxHeight < compactHubMaxHeight || maxWidth < 360;
}
