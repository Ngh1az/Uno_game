import 'dart:math';

import 'uno_card.dart';

/// Tạo và quản lý bộ bài UNO chuẩn (108 lá).
class UnoDeck {
  /// 4 màu cơ bản (không tính wild).
  static const List<CardColor> colors = [
    CardColor.red,
    CardColor.yellow,
    CardColor.green,
    CardColor.blue,
  ];

  /// Dựng bộ bài UNO tiêu chuẩn 108 lá:
  /// - Mỗi màu: 1 lá số 0, hai lá mỗi số 1..9, hai lá Skip/Reverse/+2.
  /// - 4 lá Wild và 4 lá Wild +4.
  static List<UnoCard> buildStandardDeck() {
    final deck = <UnoCard>[];

    for (final color in colors) {
      // Một lá số 0
      deck.add(UnoCard(color: color, type: CardType.number, number: 0));
      // Hai lá cho mỗi số 1..9
      for (var n = 1; n <= 9; n++) {
        deck.add(UnoCard(color: color, type: CardType.number, number: n));
        deck.add(UnoCard(color: color, type: CardType.number, number: n));
      }
      // Hai lá cho mỗi loại hành động
      for (final t in [CardType.skip, CardType.reverse, CardType.drawTwo]) {
        deck.add(UnoCard(color: color, type: t));
        deck.add(UnoCard(color: color, type: t));
      }
    }

    // 4 Wild + 4 Wild +4
    for (var i = 0; i < 4; i++) {
      deck.add(const UnoCard(color: CardColor.wild, type: CardType.wild));
      deck.add(
        const UnoCard(color: CardColor.wild, type: CardType.wildDrawFour),
      );
    }

    return deck;
  }

  /// Danh sách các lá bài khác nhau (54 mặt ảnh) — dùng để xem trước/kiểm tra ảnh.
  static List<UnoCard> uniqueFaces() {
    final faces = <UnoCard>[];
    for (final color in colors) {
      for (var n = 0; n <= 9; n++) {
        faces.add(UnoCard(color: color, type: CardType.number, number: n));
      }
      faces.add(UnoCard(color: color, type: CardType.skip));
      faces.add(UnoCard(color: color, type: CardType.reverse));
      faces.add(UnoCard(color: color, type: CardType.drawTwo));
    }
    faces.add(const UnoCard(color: CardColor.wild, type: CardType.wild));
    faces.add(const UnoCard(color: CardColor.wild, type: CardType.wildDrawFour));
    return faces;
  }

  /// Trả về bản sao đã xáo trộn của [cards].
  static List<UnoCard> shuffled(List<UnoCard> cards, {Random? random}) {
    final copy = List<UnoCard>.of(cards);
    copy.shuffle(random ?? Random());
    return copy;
  }

  /// Tạo bộ bài chuẩn đã xáo sẵn.
  static List<UnoCard> buildShuffledDeck({Random? random}) {
    return shuffled(buildStandardDeck(), random: random);
  }
}
