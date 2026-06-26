import 'package:flutter/material.dart';

import '../../models/uno_card.dart';
import '../uno_card_widget.dart';
import 'game_hand_layout.dart';
import 'game_theme.dart';

/// Tap callback: card, index trong tay, tâm lá trên màn hình (cho animation).
typedef HandCardTapCallback = void Function(
  UnoCard card,
  int index,
  Offset globalCenter,
);

/// Hàng tay bài người chơi — dùng chung offline & online.
class GamePlayerHandStrip extends StatefulWidget {
  const GamePlayerHandStrip({
    super.key,
    required this.cards,
    required this.isMyTurn,
    required this.canPlay,
    required this.onCardTap,
    this.showHints = true,
    this.selectedIndex,
    this.resetToken = 0,
  });

  final List<UnoCard> cards;
  final bool isMyTurn;
  final bool showHints;
  final bool Function(UnoCard card) canPlay;
  final HandCardTapCallback onCardTap;
  final int? selectedIndex;
  final int resetToken;

  @override
  State<GamePlayerHandStrip> createState() => _GamePlayerHandStripState();
}

class _GamePlayerHandStripState extends State<GamePlayerHandStrip> {
  late final ScrollController _scroll;
  int _dotIndex = 0;
  int _lastResetToken = 0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_syncDots);
    _lastResetToken = widget.resetToken;
  }

  @override
  void didUpdateWidget(GamePlayerHandStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != _lastResetToken) {
      _lastResetToken = widget.resetToken;
      _resetScroll();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
      if (_dotIndex != 0) setState(() => _dotIndex = 0);
    });
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
    final dotCount = cards.isEmpty ? 1 : layout.dotCountFor(cards.length);
    final activeDot = _dotIndex.clamp(0, dotCount - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: layout.stripHeight,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.symmetric(
              horizontal: GameHandLayout.horizontalPadding,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final card = cards[i];
              return Padding(
                key: ValueKey('hand-slot-$i-${card.label}'),
                padding: EdgeInsets.only(
                  right: i < cards.length - 1 ? layout.gap : 0,
                ),
                child: _cardTile(
                  card: card,
                  index: i,
                  layout: layout,
                ),
              );
            },
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
  }) {
    final playable = widget.canPlay(card);
    final hintsOn = widget.showHints && widget.isMyTurn;
    final selected = widget.selectedIndex == index;
    final raised = selected
        ? layout.lift
        : (playable && hintsOn && widget.selectedIndex == null)
            ? layout.lift * 0.35
            : 0.0;

    return SizedBox(
      width: layout.cardWidth,
      height: layout.cardHeight,
      child: GestureDetector(
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          final globalCenter = box != null
              ? box.localToGlobal(box.size.center(Offset.zero))
              : Offset.zero;
          widget.onCardTap(card, index, globalCenter);
        },
        child: Transform.translate(
          offset: Offset(0, -raised),
          child: Opacity(
            opacity: !hintsOn || playable || !widget.isMyTurn ? 1 : 0.38,
            child: Material(
              color: Colors.transparent,
              elevation: selected ? 8 : 3,
              shadowColor: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? Border.all(color: GameTheme.gold, width: 2.5)
                      : null,
                  boxShadow: hintsOn && (selected || playable)
                      ? [
                          BoxShadow(
                            color: (selected ? GameTheme.gold : unoColor(card.color))
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: UnoCardWidget(card: card, width: layout.cardWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
