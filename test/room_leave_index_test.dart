import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/models/uno_player.dart';
import 'package:uno_game/online/room_leave_logic.dart';

void main() {
  group('adjustCurrentPlayerIndexAfterLeave', () {
    test('Rời khi đang lượt: người kế giữ cùng index', () {
      final players = [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
        UnoPlayer(id: 'c', name: 'C'),
      ];
      final result = removePlayerFromGame(
        players: players,
        currentPlayerIndex: 1,
        leaverId: 'b',
      );
      expect(result.players[result.currentPlayerIndex].id, 'c');
    });

    test('Rời trước người đang lượt: lùi index', () {
      final players = [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
        UnoPlayer(id: 'c', name: 'C'),
      ];
      final result = removePlayerFromGame(
        players: players,
        currentPlayerIndex: 2,
        leaverId: 'a',
      );
      expect(result.currentPlayerIndex, 1);
      expect(result.players[result.currentPlayerIndex].id, 'c');
    });

    test('Rời người cuối khi đang lượt: quay về 0', () {
      final players = [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
      ];
      final result = removePlayerFromGame(
        players: players,
        currentPlayerIndex: 1,
        leaverId: 'b',
      );
      expect(result.currentPlayerIndex, 0);
      expect(result.players[result.currentPlayerIndex].id, 'a');
    });

    test('Leaver không có trong ván → không đổi', () {
      final players = [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
      ];
      final result = removePlayerFromGame(
        players: players,
        currentPlayerIndex: 0,
        leaverId: 'ghost',
      );
      expect(result.players.length, 2);
      expect(result.currentPlayerIndex, 0);
    });

    test('removePlayerFromGameInPlace mutate list gốc', () {
      final players = [
        UnoPlayer(id: 'a', name: 'A'),
        UnoPlayer(id: 'b', name: 'B'),
      ];
      final next = removePlayerFromGameInPlace(
        players: players,
        currentPlayerIndex: 1,
        leaverId: 'b',
      );
      expect(next, 0);
      expect(players.length, 1);
      expect(players.single.id, 'a');
    });
  });

  group('resolveHostIdAfterRemoval', () {
    test('Host còn trong phòng → giữ nguyên', () {
      expect(
        resolveHostIdAfterRemoval(
          currentHostId: 'host',
          remainingMemberIdsInOrder: ['host', 'b'],
        ),
        'host',
      );
    });

    test('Host đã rời → chuyển cho người đầu tiên còn lại', () {
      expect(
        resolveHostIdAfterRemoval(
          currentHostId: 'host',
          remainingMemberIdsInOrder: ['b', 'c'],
        ),
        'b',
      );
    });
  });
}
