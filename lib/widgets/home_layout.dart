import 'package:flutter/material.dart';

/// Kích thước dùng chung cho các khối nội dung trên Home.
abstract final class HomeLayout {
  static double padH(BuildContext context) {
    return (MediaQuery.sizeOf(context).width * 0.065).clamp(18.0, 32.0);
  }

  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 600 ? width : 440.0;
  }

  static EdgeInsets contentPadding(BuildContext context) {
    final h = padH(context);
    return EdgeInsets.symmetric(horizontal: h);
  }
}
