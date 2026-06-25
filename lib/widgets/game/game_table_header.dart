import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../models/uno_card.dart';
import '../uno_card_widget.dart';
import '../uno_circle_button.dart';
import 'game_theme.dart';

/// Header tối giản: back trái, tiêu đề giữa, chiều/màu/settings phải.
class GameTableHeader extends StatelessWidget {
  const GameTableHeader({
    super.key,
    required this.game,
    required this.onBack,
    this.title,
    this.onSettings,
    this.compactBack = true,
    this.showBack = true,
    this.showSettings = true,
  });

  final GameState game;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final String? title;
  /// Nút back nhỏ hơn, khó bấm nhầm khi đang chơi.
  final bool compactBack;
  final bool showBack;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBack)
                    UnoCircleButton(
                      icon: Icons.arrow_back,
                      label: '',
                      showLabel: false,
                      size: compactBack ? 38 : 44,
                      iconScale: compactBack ? 0.48 : 0.52,
                      onTap: onBack,
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    game.direction == PlayDirection.clockwise
                        ? Icons.rotate_right
                        : Icons.rotate_left,
                    color: GameTheme.gold.withValues(alpha: 0.85),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: unoColor(game.activeColor),
                      shape: BoxShape.circle,
                      border: Border.all(color: GameTheme.gold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: unoColor(game.activeColor).withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (showSettings && onSettings != null) ...[
                    const SizedBox(width: 6),
                    UnoCircleButton(
                      icon: Icons.settings_rounded,
                      label: '',
                      showLabel: false,
                      size: compactBack ? 38 : 44,
                      iconScale: compactBack ? 0.48 : 0.52,
                      onTap: onSettings!,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: Text(
                title!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
