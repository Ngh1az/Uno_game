import 'package:flutter/material.dart';

import 'game_theme.dart';

/// Một dòng trạng thái lượt + nút hành động khi cần (Qua lượt / UNO!).
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    super.key,
    required this.isMyTurn,
    required this.turnLabel,
    this.canPass = false,
    this.onPass,
    this.showUnoButton = false,
    this.onUno,
    this.showCatchUnoButton = false,
    this.catchUnoLabel = 'Bắt UNO',
    this.onCatchUno,
    this.drawStackCount = 0,
    this.turnSecondsRemaining,
  });

  final bool isMyTurn;
  final String turnLabel;
  final bool canPass;
  final VoidCallback? onPass;
  final bool showUnoButton;
  final VoidCallback? onUno;
  final bool showCatchUnoButton;
  final String catchUnoLabel;
  final VoidCallback? onCatchUno;
  final int drawStackCount;
  final int? turnSecondsRemaining;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _statusPill(
            label: turnLabel,
            highlight: isMyTurn,
            icon: isMyTurn ? Icons.bolt_rounded : null,
          ),
          if (canPass && onPass != null) ...[
            const SizedBox(width: 8),
            _actionPill(label: 'Qua lượt', onTap: onPass!),
          ],
          if (showUnoButton && onUno != null) ...[
            const SizedBox(width: 8),
            _actionPill(label: 'UNO!', onTap: onUno!, accent: true),
          ],
          if (showCatchUnoButton && onCatchUno != null) ...[
            const SizedBox(width: 8),
            _actionPill(label: catchUnoLabel, onTap: onCatchUno!),
          ],
          if (drawStackCount > 0 && isMyTurn) ...[
            const SizedBox(width: 8),
            _statusPill(
              label: 'Chuỗi +$drawStackCount',
              highlight: true,
              icon: Icons.layers_rounded,
            ),
          ],
          if (turnSecondsRemaining != null) ...[
            const SizedBox(width: 8),
            _timerPill(turnSecondsRemaining!),
          ],
        ],
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required bool highlight,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA1A0505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? GameTheme.gold : const Color(0x44FFFFFF),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: GameTheme.gold.withValues(alpha: 0.25), blurRadius: 10)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: GameTheme.gold, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: highlight ? GameTheme.gold : Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerPill(int seconds) {
    final urgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xCC4A0000) : const Color(0xAA1A0505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: urgent ? const Color(0xFFFF5252) : const Color(0x55FFFFFF),
          width: urgent ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: urgent ? const Color(0xFFFF5252) : Colors.white60,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${seconds}s',
            style: TextStyle(
              color: urgent ? const Color(0xFFFF8A80) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent ? const Color(0xFFE53935) : const Color(0xFF3A1010),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent ? GameTheme.gold : const Color(0x55FFD54F),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent ? GameTheme.gold : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
