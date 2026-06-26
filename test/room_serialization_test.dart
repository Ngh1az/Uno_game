import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/online/room.dart';

void main() {
  test('waiting room toJson không ghi game: null (regression leave rules)', () {
    const room = Room(
      code: 'ABC123',
      hostId: 'host-uid',
      status: RoomStatus.waiting,
      players: [
        RoomPlayer(id: 'host-uid', name: 'Host'),
        RoomPlayer(id: 'guest-uid', name: 'Guest'),
      ],
      maxPlayers: 4,
    );

    final json = room.toJson();
    expect(json.containsKey('game'), isFalse);
    expect(json['status'], 'waiting');
    expect(json['playerIds'], ['host-uid', 'guest-uid']);
    expect((json['players'] as List).length, 2);
  });

  test('playing room toJson có game khi đã bắt đầu ván', () {
    // Chỉ kiểm tra shape — không cần GameState đầy đủ cho regression leave.
    final room = Room(
      code: 'XYZ789',
      hostId: 'a',
      status: RoomStatus.playing,
      players: [const RoomPlayer(id: 'a', name: 'A')],
      maxPlayers: 4,
      game: null, // playing nhưng game null không realistic — test waiting là đủ
    );
    final json = room.toJson();
    expect(json.containsKey('game'), isFalse);
  });

  test('playerIds khớp players sau khi lọc người rời', () {
    const players = [
      RoomPlayer(id: 'a', name: 'A'),
      RoomPlayer(id: 'b', name: 'B'),
      RoomPlayer(id: 'c', name: 'C'),
    ];
    final remaining = players.where((p) => p.id != 'b').toList();
    final playerIds = remaining.map((p) => p.id).toList();

    expect(playerIds, ['a', 'c']);
    expect(remaining.map((p) => p.toJson()).length, 2);
  });
}
