import 'package:flutter/material.dart';

import '../../models/uno_card.dart';
import '../uno_card_widget.dart';
import 'game_theme.dart';

/// Dialog premium đỏ–vàng: chọn màu Wild và kết thúc ván.
abstract final class GamePremiumDialog {
  static Future<bool> confirmLeave(
    BuildContext context, {
    String title = 'Rời ván?',
    String message = 'Bạn có chắc muốn thoát? Tiến trình ván hiện tại sẽ không được lưu.',
    String confirmLabel = 'Rời ván',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GameTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x44FFD54F)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: GameTheme.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        'Ở lại',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: GameTheme.gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: GameTheme.gold,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  static Future<CardColor?> pickColor(BuildContext context) {
    return showDialog<CardColor>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GameTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x44FFD54F)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn màu',
                style: TextStyle(
                  color: GameTheme.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in [
                    CardColor.red,
                    CardColor.yellow,
                    CardColor.green,
                    CardColor.blue,
                  ])
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(c),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: unoColor(c),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: GameTheme.gold, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: unoColor(c).withValues(alpha: 0.45),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unoColorName(c),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showWin({
    required BuildContext context,
    required bool youWon,
    required String winnerName,
    required String leaveLabel,
    required VoidCallback onLeave,
    String? replayLabel,
    VoidCallback? onReplay,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: GameTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x44FFD54F)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                youWon ? '🎉' : '🃏',
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 12),
              Text(
                youWon ? 'Bạn thắng!' : 'Kết thúc',
                style: const TextStyle(
                  color: GameTheme.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                youWon
                    ? 'Chúc mừng, bạn đã hết bài!'
                    : '$winnerName đã thắng.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onLeave();
                      },
                      child: Text(
                        leaveLabel,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  if (onReplay != null && replayLabel != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: GameTheme.gold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: GameTheme.gold,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onReplay();
                        },
                        child: Text(
                          replayLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showKicked(
    BuildContext context, {
    VoidCallback? onLeave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: GameTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x44FFD54F)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bạn đã bị chủ phòng đuổi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GameTheme.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: GameTheme.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: GameTheme.gold,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onLeave?.call();
                  },
                  child: const Text(
                    'Về sảnh',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
