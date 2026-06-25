import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

/// Mở màn cài đặt đầy đủ (dùng trong trận, login, v.v.).
class SettingsSheet {
  SettingsSheet._();

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
