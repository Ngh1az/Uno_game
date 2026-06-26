import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../uno_circle_button.dart';

/// Header tối giản: back trái, tiêu đề giữa, nút phụ phải.
class GameTableHeader extends StatelessWidget {
  const GameTableHeader({
    super.key,
    required this.game,
    required this.onBack,
    this.title,
    this.onSettings,
    this.onPlayersList,
    this.compactBack = true,
    this.showBack = true,
    this.showSettings = true,
    this.showPlayersList = false,
  });

  final GameState game;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onPlayersList;
  final String? title;
  /// Nút back nhỏ hơn, khó bấm nhầm khi đang chơi.
  final bool compactBack;
  final bool showBack;
  final bool showSettings;
  final bool showPlayersList;

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
                  if (showPlayersList && onPlayersList != null)
                    UnoCircleButton(
                      icon: Icons.groups_rounded,
                      label: '',
                      showLabel: false,
                      size: compactBack ? 38 : 44,
                      iconScale: compactBack ? 0.48 : 0.52,
                      onTap: onPlayersList!,
                    ),
                  if (showSettings && onSettings != null) ...[
                    if (showPlayersList && onPlayersList != null)
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
