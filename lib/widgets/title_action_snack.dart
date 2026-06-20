import 'package:flutter/material.dart';

import '../titles/title_definition.dart';
import 'app_snack.dart';

/// Thông báo đẹp khi đeo / bỏ đeo / thao tác danh hiệu.
abstract final class TitleActionSnack {
  static void showEquipped(BuildContext context, TitleDefinition title) {
    AppSnack.success(
      context,
      'Đã đeo danh hiệu',
      detail: title.name,
      accent: title.color,
      icon: title.icon,
    );
  }

  static void showUnequipped(BuildContext context) {
    AppSnack.show(
      context,
      message: 'Đã bỏ danh hiệu',
      detail: 'Không hiển thị trên Home',
      accent: Colors.white54,
      icon: Icons.highlight_off_rounded,
      trailing: const Icon(
        Icons.check_circle_outline_rounded,
        color: Colors.white38,
        size: 22,
      ),
    );
  }

  static void showMessage(
    BuildContext context,
    String headline, {
    String? body,
    bool success = true,
    Color? accent,
    IconData? icon,
  }) {
    if (success) {
      AppSnack.success(
        context,
        headline,
        detail: body,
        accent: accent ?? AppSnack.gold,
        icon: icon ?? Icons.emoji_events_rounded,
      );
    } else {
      AppSnack.error(context, headline);
    }
  }
}
