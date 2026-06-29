import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/game/auto_turn_player.dart';
import 'package:uno_game/game/turn_timeout_policy.dart';
import 'package:uno_game/models/game_state.dart';
import 'package:uno_game/models/uno_card.dart';
import 'package:uno_game/models/uno_player.dart';
import 'package:uno_game/online/room_leave_logic.dart';

void main() {
  test('TurnTimeoutPolicy có giá trị hợp lý', () {
    expect(TurnTimeoutPolicy.turnDuration.inSeconds, 60);
    expect(TurnTimeoutPolicy.maxStrikes, 3);
  });

  test('forfeitPlayerInGame — 2 người thì người còn lại thắng', () {
    final players = [
      UnoPlayer(id: 'a', name: 'A'),
      UnoPlayer(id: 'b', name: 'B'),
    ];
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

    final finished = forfeitPlayerInGame(
      game: g,
      playerId: 'b',
      playerName: 'B',
      reason: 'treo máy quá lâu',
    );

    expect(finished, isTrue);
    expect(g.status, GameStatus.finished);
    expect(g.winnerId, 'a');
    expect(g.players.length, 1);
  });

  test('forfeitPlayerInGame — chỉnh currentPlayerIndex khi còn 1 người', () {
    final players = [
      UnoPlayer(id: 'a', name: 'A'),
      UnoPlayer(id: 'b', name: 'B'),
    ];
    final g = GameState(
      players: players,
      drawPile: [const UnoCard(color: CardColor.blue, type: CardType.number, number: 1)],
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 2),
      ],
      currentPlayerIndex: 1,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );

    final finished = forfeitPlayerInGame(
      game: g,
      playerId: 'b',
      playerName: 'B',
      reason: 'đã rời ván',
    );

    expect(finished, isTrue);
    expect(g.players.length, 1);
    expect(g.currentPlayerIndex, 0);
    expect(g.currentPlayer.id, 'a');
  });

  test('wonByForfeit — true sau khi đối thủ rời ván', () {
    final players = [
      UnoPlayer(id: 'a', name: 'A'),
      UnoPlayer(id: 'b', name: 'B'),
    ];
    players[0].hand.add(
      const UnoCard(color: CardColor.red, type: CardType.number, number: 3),
    );
    final g = GameState(
      players: players,
      drawPile: [const UnoCard(color: CardColor.blue, type: CardType.number, number: 1)],
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 2),
      ],
      currentPlayerIndex: 1,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );

    forfeitPlayerInGame(
      game: g,
      playerId: 'b',
      playerName: 'B',
      reason: 'đã rời ván',
    );

    expect(g.wonByForfeit, isTrue);
    expect(g.winnerId, 'a');
  });

  test('AutoTurnPlayer hoàn thành lượt khi có lá đánh được', () {
    final players = [
      UnoPlayer(id: 'p1', name: 'A'),
      UnoPlayer(id: 'p2', name: 'B'),
    ];
    players[0].hand.addAll([
      const UnoCard(color: CardColor.red, type: CardType.number, number: 5),
      const UnoCard(color: CardColor.blue, type: CardType.number, number: 3),
    ]);
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

    AutoTurnPlayer.takeTurn(g, autoUno: true);
    expect(g.currentPlayer.id, 'p2');
  });

  test('syncGamePlayersWithMembers gỡ người không còn trong phòng', () {
    final g = GameState(
      players: [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
      ],
      drawPile: [],
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 2),
      ],
      currentPlayerIndex: 1,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );
    syncGamePlayersWithMembers(game: g, memberIds: {'a'});
    expect(g.players.length, 1);
    expect(g.players.first.id, 'a');
    expect(g.currentPlayerIndex, 0);
  });

  test('timeoutStrikes tăng và reset', () {
    final g = GameState(
      players: [
        UnoPlayer(id: 'p1', name: 'A'),
        UnoPlayer(id: 'p2', name: 'B'),
      ],
      drawPile: [],
      discardPile: [
        const UnoCard(color: CardColor.red, type: CardType.number, number: 2),
      ],
      currentPlayerIndex: 0,
      direction: PlayDirection.clockwise,
      activeColor: CardColor.red,
      status: GameStatus.playing,
    );

    g.incrementTimeoutStrike('p1');
    g.incrementTimeoutStrike('p1');
    expect(g.timeoutStrikeCount('p1'), 2);
    g.resetTimeoutStrike('p1');
    expect(g.timeoutStrikeCount('p1'), 0);
  });
}
