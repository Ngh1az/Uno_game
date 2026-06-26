import 'package:flutter/material.dart';

import '../../widgets/uno_card_widget.dart';

/// Kích thước tay bài — luôn cuộn ngang phẳng (không fan).
class GameHandLayout {
  const GameHandLayout({
    required this.cardWidth,
    required this.lift,
    required this.gap,
    required this.cardsPerPage,
  });

  static const double horizontalPadding = 16;
  static const double introVerticalPadding = 10;

  final double cardWidth;
  final double lift;
  final double gap;
  final int cardsPerPage;

  double get cardHeight => cardWidth * UnoCardWidget.aspectRatio;

  double get stripHeight => cardHeight + lift + 6;

  static GameHandLayout compute({
    required double viewportWidth,
    required int cardCount,
  }) {
    const pad = 32.0;
    const gap = 4.0;
    final usable = viewportWidth - pad;

    final cardW = cardCount > 10
        ? (viewportWidth * 0.15).clamp(54.0, 62.0)
        : (viewportWidth * 0.17).clamp(62.0, 76.0);

    return GameHandLayout(
      cardWidth: cardW,
      lift: 12,
      gap: gap,
      cardsPerPage: _visibleCards(usable, cardW, gap),
    );
  }

  static int _visibleCards(double usable, double cardW, double gap) {
    final perPage = (usable / (cardW + gap)).floor();
    return perPage.clamp(3, 6);
  }

  double scrollPageWidth() => (cardWidth + gap) * cardsPerPage;

  bool needsScrollHint(int cardCount) => cardCount > cardsPerPage;

  int dotCountFor(int cardCount) {
    if (cardCount <= 0) return 1;
    return ((cardCount - 1) / cardsPerPage).floor() + 1;
  }

  /// Chiều cao đủ cho cả hàng lá + gợi ý vuốt + chấm trang.
  double totalHeight(int cardCount) {
    var h = stripHeight;
    if (needsScrollHint(cardCount)) {
      h += 6 + 16; // spacing + hint text line
    }
    h += 8;
    if (dotCountFor(cardCount) > 1) {
      h += 8;
    }
    return h;
  }

  /// Tâm lá [cardIndex] trong hệ tọa độ local của vùng tay bài.
  Offset slotLocalCenter(int cardIndex, {bool introStrip = false}) {
    final y = introStrip
        ? introVerticalPadding + stripHeight / 2
        : stripHeight / 2;
    return Offset(
      horizontalPadding +
          cardIndex * (cardWidth + gap) +
          cardWidth / 2,
      y,
    );
  }
}
