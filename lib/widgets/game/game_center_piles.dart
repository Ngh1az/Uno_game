import 'package:flutter/material.dart';

import '../../models/uno_card.dart';
import '../uno_card_widget.dart';
import 'game_theme.dart';

/// Chồng bài đánh + rút ở giữa bàn.
class GameCenterPiles extends StatelessWidget {
  const GameCenterPiles({
    super.key,
    required this.topCard,
    required this.activeColor,
    required this.canDraw,
    this.onDraw,
    this.drawPileCount,
    this.discardKey,
    this.drawKey,
    this.drawFlyKey,
    this.discardCount,
    this.hideDiscard = false,
  });

  final UnoCard topCard;
  final CardColor activeColor;
  final bool canDraw;
  final VoidCallback? onDraw;
  final int? drawPileCount;
  final GlobalKey? discardKey;
  final GlobalKey? drawKey;
  /// Key trên lá úp chồng rút — dùng làm điểm xuất phát hoạt ảnh chia bài.
  final GlobalKey? drawFlyKey;
  final int? discardCount;
  /// Chỉ hiện 1 chồng úp giữa bàn (intro 3-2-1 / chia bài).
  final bool hideDiscard;

  @override
  Widget build(BuildContext context) {
    final active = unoColor(activeColor);
    final pileW = GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width);

    if (hideDiscard) {
      return Center(
        child: _pileCard(
          key: drawKey,
          glow: GameTheme.gold.withValues(alpha: 0.45),
          pileW: pileW,
          badge: (drawPileCount ?? 0) + 1,
          child: drawFlyKey != null
              ? KeyedSubtree(
                  key: drawFlyKey,
                  child: UnoCardBack(width: pileW),
                )
              : UnoCardBack(width: pileW),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pileCard(
          key: discardKey,
          glow: active,
          pileW: pileW,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: UnoCardWidget(
              key: ValueKey(discardCount ?? topCard.hashCode),
              card: topCard,
              width: pileW,
            ),
          ),
        ),
        SizedBox(width: pileW * 0.55),
        _pileCard(
          key: drawKey,
          glow: canDraw ? GameTheme.gold : const Color(0xFF5C5C5C),
          dimmed: !canDraw,
          hint: canDraw ? 'Rút' : null,
          badge: drawPileCount,
          pileW: pileW,
          onTap: canDraw ? onDraw : null,
          child: drawFlyKey != null
              ? KeyedSubtree(
                  key: drawFlyKey,
                  child: UnoCardBack(width: pileW),
                )
              : UnoCardBack(width: pileW),
        ),
      ],
    );
  }

  Widget _pileCard({
    Key? key,
    required Color glow,
    required double pileW,
    required Widget child,
    String? hint,
    int? badge,
    bool dimmed = false,
    VoidCallback? onTap,
  }) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: dimmed ? 0.15 : 0.5),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: dimmed ? 0.55 : 1, child: child),
          if (badge != null && badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0505),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GameTheme.gold.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: GameTheme.gold,
                    fontSize: pileW * 0.13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap != null)
          GestureDetector(onTap: onTap, child: card)
        else
          card,
        SizedBox(
          height: hint != null ? pileW * 0.24 : 0,
          child: hint != null
              ? Padding(
                  padding: EdgeInsets.only(top: pileW * 0.08),
                  child: Text(
                    hint,
                    style: TextStyle(
                      color: glow.withValues(alpha: 0.95),
                      fontSize: pileW * 0.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
