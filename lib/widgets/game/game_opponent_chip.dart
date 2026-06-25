import 'package:flutter/material.dart';

import '../../models/uno_player.dart';
import '../../titles/title_definition.dart';
import '../uno_card_widget.dart';
import '../user_avatar.dart';
import 'game_theme.dart';
import 'opponent_chip_density.dart';
import 'title_mini_badge.dart';

/// Chip đối thủ/bot: avatar + danh hiệu + tên + badge số lá.
class GameOpponentChip extends StatelessWidget {
  final int? cardCountOverride;
  final GlobalKey? avatarFlyKey;

  const GameOpponentChip({
    super.key,
    required this.player,
    required this.isTurn,
    required this.density,
    this.isBot = false,
    this.useCardBack = false,
    this.thinking = false,
    this.photoUrl,
    this.equippedTitleId,
    this.cardCountOverride,
    this.avatarFlyKey,
    this.catchableUno = false,
    this.onCatchUno,
  });

  final UnoPlayer player;
  final bool isTurn;
  final bool isBot;
  final bool useCardBack;
  final bool thinking;
  final OpponentChipDensity density;
  final String? photoUrl;
  final String? equippedTitleId;
  final bool catchableUno;
  final VoidCallback? onCatchUno;

  @override
  Widget build(BuildContext context) {
    if (isBot) return _buildBotChip();
    return _buildHumanChip();
  }

  Widget _buildBotChip() {
    final name = _truncateName(player.name, density.nameMaxChars);
    final avatarR = density.botAvatarRadius;
    final nameStyle = TextStyle(
      color: isTurn ? GameTheme.gold : Colors.white70,
      fontSize: density == OpponentChipDensity.roomy ? 9 : 8,
      fontWeight: FontWeight.w800,
    );

    return SizedBox(
      height: density.botRowHeight,
      child: GestureDetector(
        onTap: catchableUno ? onCatchUno : null,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedScale(
            scale: isTurn ? 1.04 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTurn ? GameTheme.gold : const Color(0x33FFFFFF),
                  width: isTurn ? 2 : 1,
                ),
                boxShadow: isTurn
                    ? [
                        BoxShadow(
                          color: GameTheme.gold.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: avatarR,
                    backgroundColor: const Color(0xFF3A1010),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: isTurn ? GameTheme.gold : Colors.white54,
                      size: avatarR * 0.95,
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -1,
                    child: _cardCountBadge(),
                  ),
                  if (thinking) _thinkingRing(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            name,
            style: nameStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (player.hasUno) _unoLabel(),
          if (catchableUno) _catchableLabel(),
        ],
        ),
      ),
    );
  }

  Widget _buildHumanChip() {
    final title = equippedTitleId == null ? null : titleById(equippedTitleId!);
    final showTitleText = title != null && density.showTitleText(isTurn);
    final name = _truncateName(player.name, density.nameMaxChars);
    final nameStyle = TextStyle(
      color: isTurn ? GameTheme.gold : Colors.white70,
      fontSize: density.nameFontSize,
      fontWeight: FontWeight.w800,
    );

    return SizedBox(
      height: density.rowHeight,
      child: GestureDetector(
        onTap: catchableUno ? onCatchUno : null,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (title != null)
            TitleMiniBadge(
              title: title,
              showText: showTitleText,
              maxChars: density.nameMaxChars,
            ),
          AnimatedScale(
            scale: isTurn ? 1.05 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: KeyedSubtree(
              key: avatarFlyKey,
              child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTurn ? GameTheme.gold : const Color(0x33FFFFFF),
                  width: isTurn ? 2.5 : 1,
                ),
                boxShadow: isTurn
                    ? [
                        BoxShadow(
                          color: GameTheme.gold.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (useCardBack)
                    UnoCardBack(width: density.cardBackWidth)
                  else
                    UserAvatar(
                      photoUrl: photoUrl,
                      displayName: player.name,
                      radius: density.avatarRadius,
                    ),
                  if (title != null) TitleCornerBadge(title: title),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: _cardCountBadge(),
                  ),
                  if (thinking) _thinkingRing(),
                ],
              ),
            ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: nameStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (player.hasUno) _unoLabel(),
          if (catchableUno) _catchableLabel(),
        ],
        ),
      ),
    );
  }

  Widget _cardCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0505),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTurn ? GameTheme.gold : const Color(0x44FFFFFF),
        ),
      ),
      child: Text(
        '${cardCountOverride ?? player.hand.length}',
        style: TextStyle(
          color: isTurn ? GameTheme.gold : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _thinkingRing() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: GameTheme.gold.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _unoLabel() {
    return const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Text(
        'UNO!',
        style: TextStyle(
          color: GameTheme.gold,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _catchableLabel() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GameTheme.gold),
        ),
        child: const Text(
          'Bắt UNO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _truncateName(String raw, int maxChars) {
    final name = raw.trim();
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars)}…';
  }
}
