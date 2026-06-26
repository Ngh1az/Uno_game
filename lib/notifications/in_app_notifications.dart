import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../widgets/app_snack.dart';

/// Thông báo trong app (popup / snack) — không dùng push hệ thống.
class InAppNotifications {
  InAppNotifications._();

  static String? _lastTurnKey;

  static bool get enabled => AppSettings.instance.notificationsEnabled;

  static bool get roomInvites =>
      enabled && AppSettings.instance.roomInviteNotifications;

  static bool get turns => enabled && AppSettings.instance.turnNotifications;

  static bool get appInBackground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
  }

  static void resetTurnDedup() => _lastTurnKey = null;

  static void notifyMyTurn(
    BuildContext context, {
    required String turnKey,
    String message = 'Đến lượt bạn!',
  }) {
    if (!turns) return;
    if (_lastTurnKey == turnKey) return;
    _lastTurnKey = turnKey;
    if (AppSettings.instance.vibrationEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
    AppSnack.info(context, message, icon: Icons.swap_horiz);
  }
}
