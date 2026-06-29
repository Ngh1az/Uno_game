import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/models/game_state.dart';
import 'package:uno_game/models/uno_card.dart';
import 'package:uno_game/models/uno_player.dart';

void main() {
  test('GameState toJson/fromJson giữ trạng thái chính', () {
    final original = GameState.newGame(
      players: [
        UnoPlayer(id: 'u1', name: 'Một'),
        UnoPlayer(id: 'u2', name: 'Hai'),
      ],
      random: Random(42),
    );
    original.pendingDrawCount = 4;
    original.unoDeclaredBeforePlay.add('u1');

    final restored = GameState.fromJson(original.toJson());

    expect(restored.players.length, original.players.length);
    expect(restored.currentPlayerIndex, original.currentPlayerIndex);
    expect(restored.direction, original.direction);
    expect(restored.activeColor, original.activeColor);
    expect(restored.status, original.status);
    expect(restored.pendingDrawCount, 4);
    expect(restored.unoDeclaredBeforePlay, contains('u1'));
    expect(restored.topCard.label, original.topCard.label);
    expect(
      restored.players.first.hand.length,
      original.players.first.hand.length,
    );
  });

  test('fromJson clamp currentPlayerIndex khi lệch số người', () {
    final player = UnoPlayer(id: 'a', name: 'A');
    final json = {
      'players': [player.toJson()],
      'drawPile': [],
      'discardPile': [],
      'currentPlayerIndex': 1,
      'direction': PlayDirection.clockwise.name,
      'activeColor': CardColor.red.name,
      'status': GameStatus.finished.name,
      'winnerId': 'a',
      'drawnThisTurn': false,
      'pendingDrawCount': 0,
      'log': <String>[],
    };

    final restored = GameState.fromJson(json);

    expect(restored.players.length, 1);
    expect(restored.currentPlayerIndex, 0);
    expect(restored.currentPlayer.id, 'a');
  });
}
