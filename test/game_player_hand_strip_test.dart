import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/models/uno_card.dart';
import 'package:uno_game/widgets/game/game_player_hand_strip.dart';
import 'package:uno_game/widgets/uno_card_widget.dart';

List<UnoCard> _sampleHand(int count) {
  const colors = [CardColor.red, CardColor.yellow, CardColor.green, CardColor.blue];
  return List.generate(count, (i) {
    return UnoCard(
      color: colors[i % colors.length],
      type: CardType.number,
      number: i % 10,
    );
  });
}

void main() {
  testWidgets('GamePlayerHandStrip renders all 7 cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamePlayerHandStrip(
            cards: _sampleHand(7),
            isMyTurn: true,
            canPlay: (_) => true,
            onCardTap: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnoCardWidget), findsNWidgets(7));
  });

  testWidgets('resetToken keeps all 7 cards visible after rebuild', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));

    final cards = _sampleHand(7);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamePlayerHandStrip(
            key: const ValueKey('hand-strip'),
            cards: cards,
            isMyTurn: false,
            canPlay: (_) => false,
            resetToken: 0,
            onCardTap: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(-120, 0));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamePlayerHandStrip(
            key: const ValueKey('hand-strip'),
            cards: cards,
            isMyTurn: false,
            canPlay: (_) => false,
            resetToken: 1,
            onCardTap: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hand-slot-0-Red 0')),
      findsOneWidget,
    );
  });
}
