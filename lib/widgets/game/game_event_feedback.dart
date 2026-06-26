import 'package:flutter/material.dart';

import '../app_snack.dart';

/// Hiển thị snack ngắn cho sự kiện quan trọng trong `GameState.log`.
class GameEventFeedback {
  int _lastLogLen = 0;

  void reset() => _lastLogLen = 0;

  void onLogChanged(BuildContext context, List<String> log) {
    if (!context.mounted) return;
    if (log.length <= _lastLogLen) {
      _lastLogLen = log.length;
      return;
    }

    for (var i = log.length - 1; i >= _lastLogLen; i--) {
      final line = log[i];
      if (_shouldShow(line)) {
        AppSnack.gameEvent(
          context,
          line,
          icon: _iconFor(line),
          duration: const Duration(milliseconds: 1500),
        );
        break;
      }
    }
    _lastLogLen = log.length;
  }

  static bool _shouldShow(String line) {
    if (line.startsWith('Tới lượt')) return false;
    if (line.contains('hết giờ')) return true;
    if (line.contains('đánh ') && !line.contains('Đảo')) {
      // Bỏ qua log đánh lá thường.
      if (!line.contains('Skip') &&
          !line.contains('bốc') &&
          !line.contains('THẮNG') &&
          !line.contains('UNO')) {
        return false;
      }
    }
    return line.contains('Skip') ||
        line.contains('mất lượt') ||
        line.contains('qua lượt') ||
        line.contains('kết thúc lượt') ||
        line.contains('Đảo') ||
        line.contains('bốc 2') ||
        line.contains('bốc 4') ||
        line.contains('Trộn lại') ||
        line.contains('THẮNG') ||
        line.contains('UNO');
  }

  static IconData _iconFor(String line) {
    if (line.contains('hết giờ')) return Icons.timer_off_rounded;
    if (line.contains('THẮNG')) return Icons.emoji_events_rounded;
    if (line.contains('UNO')) return Icons.campaign_rounded;
    if (line.contains('Đảo')) return Icons.swap_horiz_rounded;
    if (line.contains('Skip') ||
        line.contains('mất lượt') ||
        line.contains('qua lượt') ||
        line.contains('kết thúc lượt')) {
      return Icons.skip_next_rounded;
    }
    if (line.contains('bốc')) return Icons.style_rounded;
    return Icons.info_outline_rounded;
  }
}
