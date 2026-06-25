import 'package:flutter/material.dart';

import '../../models/uno_card.dart';
import '../uno_card_widget.dart';
import 'game_hand_layout.dart';
import 'game_theme.dart';

/// Hàng tay bài người chơi — dùng chung offline & online.
class GamePlayerHandStrip extends StatefulWidget {
  const GamePlayerHandStrip({
    super.key,
    required this.cards,
    required this.isMyTurn,
    required this.canPlay,
    required this.onCardTap,
    this.showHints = true,
    this.flyingHandIndex,
    this.selectedCard,
    this.flyAnchorKey,
  });

  final List<UnoCard> cards;
  final bool isMyTurn;
  final bool showHints;
  final bool Function(UnoCard card) canPlay;
  final void Function(UnoCard card, int index) onCardTap;
  final int? flyingHandIndex;
  final UnoCard? selectedCard;
  final GlobalKey? flyAnchorKey;

  @override
  State<GamePlayerHandStrip> createState() => _GamePlayerHandStripState();
}

class _GamePlayerHandStripState extends State<GamePlayerHandStrip> {
  late final ScrollController _scroll;
  int _dotIndex = 0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_syncDots);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncDots() {
    if (!_scroll.hasClients || !mounted) return;
    final layout = _layout;
    final pageW = layout.scrollPageWidth();
    if (pageW <= 0) return;
    final next = (_scroll.offset / pageW).round();
    if (next != _dotIndex) setState(() => _dotIndex = next);
  }

  GameHandLayout get _layout => GameHandLayout.compute(
        viewportWidth: MediaQuery.sizeOf(context).width,
        cardCount: widget.cards.length,
      );

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final cards = widget.cards;
    final dotCount = cards.isEmpty
        ? 1
        : ((cards.length - 1) / layout.cardsPerPage).floor() + 1;
    final activeDot = _dotIndex.clamp(0, dotCount - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: layout.stripHeight,
          child: ClipRect(
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cards.length,
              separatorBuilder: (_, _) => SizedBox(width: layout.gap),
              itemBuilder: (context, i) {
                final card = cards[i];
                final isFlying = widget.flyingHandIndex == i;
                return KeyedSubtree(
                  key: ValueKey('hand-slot-$i'),
                  child: _cardTile(
                    card: card,
                    index: i,
                    layout: layout,
                    isFlying: isFlying,
                  ),
                );
              },
            ),
          ),
        ),
        if (layout.needsScrollHint(cards.length)) ...[
          const SizedBox(height: 6),
          Text(
            'Vuốt ngang để xem thêm bài',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (dotCount > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < dotCount; i++)
                Container(
                  width: i == activeDot ? 8 : 6,
                  height: i == activeDot ? 8 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == activeDot ? GameTheme.gold : Colors.white24,
                    boxShadow: i == activeDot
                        ? [
                            BoxShadow(
                              color: GameTheme.gold.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cardTile({
    required UnoCard card,
    required int index,
    required GameHandLayout layout,
    required bool isFlying,
  }) {
    final playable = widget.canPlay(card);
    final hintsOn = widget.showHints && widget.isMyTurn;
    final selected = widget.selectedCard != null &&
        identical(widget.selectedCard, card);
    final raised = selected
        ? layout.lift
        : (playable && hintsOn && widget.selectedCard == null)
            ? layout.lift * 0.35
            : 0.0;

    final tile = GestureDetector(
      onTap: isFlying ? null : () => widget.onCardTap(card, index),
      child: Transform.translate(
        offset: Offset(0, -raised),
        child: Opacity(
          opacity: !hintsOn || playable || !widget.isMyTurn ? 1 : 0.38,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(color: GameTheme.gold, width: 2.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: selected ? 14 : 6,
                  offset: const Offset(0, 4),
                ),
                if (hintsOn && (selected || playable))
                  BoxShadow(
                    color: (selected ? GameTheme.gold : unoColor(card.color))
                        .withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
              ],
            ),
            child: UnoCardWidget(card: card, width: layout.cardWidth),
          ),
        ),
      ),
    );

    if (isFlying && widget.flyAnchorKey != null) {
      return SizedBox(
        width: layout.cardWidth,
        height: layout.cardHeight,
        child: KeyedSubtree(
          key: widget.flyAnchorKey,
          child: Opacity(opacity: 0, child: tile),
        ),
      );
    }

    return tile;
  }
}
