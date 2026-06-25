import '../../widgets/uno_card_widget.dart';

/// Kích thước tay bài — luôn cuộn ngang phẳng (không fan).
class GameHandLayout {
  const GameHandLayout({
    required this.cardWidth,
    required this.lift,
    required this.gap,
    required this.cardsPerPage,
  });

  final double cardWidth;
  final double lift;
  final double gap;
  final int cardsPerPage;

  double get cardHeight => cardWidth * UnoCardWidget.aspectRatio;

  double get stripHeight => cardHeight + lift + 12;

  static GameHandLayout compute({
    required double viewportWidth,
    required int cardCount,
  }) {
    const pad = 32.0;
    final usable = viewportWidth - pad;

    final cardW = cardCount > 10
        ? (viewportWidth * 0.15).clamp(54.0, 62.0)
        : (viewportWidth * 0.17).clamp(62.0, 76.0);

    return GameHandLayout(
      cardWidth: cardW,
      lift: 16,
      gap: 8,
      cardsPerPage: _visibleCards(usable, cardW, 8),
    );
  }

  static int _visibleCards(double usable, double cardW, double gap) {
    final perPage = (usable / (cardW + gap)).floor();
    return perPage.clamp(3, 6);
  }

  double scrollPageWidth() => (cardWidth + gap) * cardsPerPage;

  bool needsScrollHint(int cardCount) => cardCount > cardsPerPage;
}
