import 'package:flutter_test/flutter_test.dart';

import 'package:uno_game/models/uno_card.dart';
import 'package:uno_game/models/uno_deck.dart';

void main() {
  test('Bộ bài chuẩn có đúng 108 lá', () {
    final deck = UnoDeck.buildStandardDeck();
    expect(deck.length, 108);
  });

  test('Có 4 lá Wild và 4 lá Wild +4', () {
    final deck = UnoDeck.buildStandardDeck();
    expect(deck.where((c) => c.type == CardType.wild).length, 4);
    expect(deck.where((c) => c.type == CardType.wildDrawFour).length, 4);
  });

  test('Luật đánh bài cơ bản', () {
    const redFive = UnoCard(
      color: CardColor.red,
      type: CardType.number,
      number: 5,
    );
    const redNine = UnoCard(
      color: CardColor.red,
      type: CardType.number,
      number: 9,
    );
    const blueFive = UnoCard(
      color: CardColor.blue,
      type: CardType.number,
      number: 5,
    );
    const blueSkip = UnoCard(color: CardColor.blue, type: CardType.skip);
    const wild = UnoCard(color: CardColor.wild, type: CardType.wild);

    // Trùng màu đỏ -> được
    expect(redNine.canPlayOn(redFive, CardColor.red), isTrue);
    // Trùng số 5 khác màu -> được
    expect(blueFive.canPlayOn(redFive, CardColor.red), isTrue);
    // Khác màu, khác số -> không được
    expect(blueSkip.canPlayOn(redFive, CardColor.red), isFalse);
    // Wild luôn đánh được
    expect(wild.canPlayOn(redFive, CardColor.red), isTrue);
  });
}
