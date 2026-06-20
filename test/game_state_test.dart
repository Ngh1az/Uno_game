import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/game/uno_bot.dart';
import 'package:uno_game/models/game_state.dart';
import 'package:uno_game/models/uno_card.dart';
import 'package:uno_game/models/uno_player.dart';

GameState _newGame({int seed = 1}) {
  final players = [
    UnoPlayer(id: 'p1', name: 'An'),
    UnoPlayer(id: 'p2', name: 'Bình', isBot: true),
    UnoPlayer(id: 'p3', name: 'Chi', isBot: true),
  ];
  return GameState.newGame(players: players, random: Random(seed));
}

void main() {
  test('Chia bài: mỗi người 7 lá, lá khởi đầu là lá số', () {
    final g = _newGame();
    for (final p in g.players) {
      expect(p.hand.length, 7);
    }
    expect(g.topCard.type, CardType.number);
    // 108 - 3*7 - 1 (lá đánh) = 86 lá còn trong chồng rút.
    expect(g.drawPile.length, 86);
    expect(g.status, GameStatus.playing);
  });

  test('Không được đánh khi chưa tới lượt', () {
    final g = _newGame();
    final notTurn = g.players[1];
    expect(
      () => g.playCard(notTurn.id, notTurn.hand.first),
      throwsA(isA<InvalidMoveException>()),
    );
  });

  test('Đánh lá hợp lệ sẽ chuyển lượt', () {
    final g = _newGame();
    final p1 = g.players[0];
    final playable = g.playableCards(p1);
    if (playable.isEmpty) return; // tuỳ seed; bỏ qua nếu bí bài
    final card = playable.firstWhere((c) => !c.isWild, orElse: () => playable.first);
    final before = g.currentPlayerIndex;
    g.playCard(p1.id, card, chosenColor: card.isWild ? CardColor.red : null);
    expect(g.currentPlayerIndex == before, isFalse);
  });

  test('Lá Skip làm mất lượt người kế tiếp', () {
    final players = [
      UnoPlayer(id: 'p1', name: 'A'),
      UnoPlayer(id: 'p2', name: 'B'),
      UnoPlayer(id: 'p3', name: 'C'),
    ];
    final skip = const UnoCard(color: CardColor.red, type: CardType.skip);
    final g = GameState(
      players: players,
      drawPile: List.generate(
        10,
        (_) => const UnoCard(color: CardColor.blue, type: CardType.number, number: 1),
      ),
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 5),
      ],
      currentPlayerIndex: 0,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );
    players[0].hand.add(skip);
    players[0].hand.add(
      const UnoCard(color: CardColor.green, type: CardType.number, number: 3),
    ); // lá độn để không thắng ngay
    g.playCard('p1', skip);
    // p2 bị skip -> tới p3 (index 2).
    expect(g.currentPlayerIndex, 2);
  });

  test('Lá +2 khiến người kế tiếp bốc 2 và mất lượt', () {
    final players = [
      UnoPlayer(id: 'p1', name: 'A'),
      UnoPlayer(id: 'p2', name: 'B'),
      UnoPlayer(id: 'p3', name: 'C'),
    ];
    final draw2 = const UnoCard(color: CardColor.red, type: CardType.drawTwo);
    final g = GameState(
      players: players,
      drawPile: List.generate(
        10,
        (_) => const UnoCard(color: CardColor.blue, type: CardType.number, number: 1),
      ),
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 5),
      ],
      currentPlayerIndex: 0,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );
    players[0].hand.add(draw2);
    players[0].hand.add(
      const UnoCard(color: CardColor.green, type: CardType.number, number: 3),
    ); // lá độn để không thắng ngay
    g.playCard('p1', draw2);
    expect(players[1].hand.length, 2); // B bốc 2
    expect(g.currentPlayerIndex, 2); // tới C
  });

  test('Hết bài thì thắng', () {
    final players = [
      UnoPlayer(id: 'p1', name: 'A'),
      UnoPlayer(id: 'p2', name: 'B'),
    ];
    final last = const UnoCard(color: CardColor.red, type: CardType.number, number: 7);
    final g = GameState(
      players: players,
      drawPile: [const UnoCard(color: CardColor.blue, type: CardType.number, number: 1)],
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 2),
      ],
      currentPlayerIndex: 0,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );
    players[0].hand.add(last);
    g.playCard('p1', last);
    expect(g.status, GameStatus.finished);
    expect(g.winnerId, 'p1');
  });

  test('Bot có thể chơi trọn ván mà không lỗi', () {
    final g = _newGame(seed: 42);
    var guard = 0;
    while (g.status == GameStatus.playing && guard < 2000) {
      final cur = g.currentPlayer;
      if (cur.isBot) {
        UnoBot.takeTurn(g);
      } else {
        // Người thật: mô phỏng bằng cách chơi như bot để ván chạy hết.
        playHumanAuto(g);
      }
      guard++;
    }
    expect(guard < 2000, isTrue, reason: 'Ván nên kết thúc trong giới hạn lượt');
    expect(g.status, GameStatus.finished);
  });
}

/// Cho người chơi 'thật' đi tự động (chỉ dùng trong test) để chạy hết ván.
void playHumanAuto(GameState g) {
  final p = g.currentPlayer;
  final playable = g.playableCards(p);
  if (playable.isNotEmpty) {
    final card = playable.firstWhere((c) => !c.isWild, orElse: () => playable.first);
    g.playCard(p.id, card, chosenColor: card.isWild ? CardColor.red : null);
  } else {
    final drawn = g.drawCard(p.id);
    if (g.status == GameStatus.playing &&
        g.currentPlayer.id == p.id &&
        g.canPlay(drawn)) {
      g.playCard(p.id, drawn, chosenColor: drawn.isWild ? CardColor.red : null);
    }
  }
}
