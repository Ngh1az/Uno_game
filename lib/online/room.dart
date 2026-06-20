import '../models/game_state.dart';

/// Trạng thái phòng chơi online.
enum RoomStatus { waiting, playing, finished }

/// Thông tin một người chơi trong phòng (lúc ở sảnh chờ).
class RoomPlayer {
  final String id; // = uid ẩn danh từ Firebase Auth
  final String name;

  const RoomPlayer({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory RoomPlayer.fromJson(Map<String, dynamic> json) =>
      RoomPlayer(id: json['id'] as String, name: json['name'] as String);
}

/// Một phòng chơi UNO online (ánh xạ tới 1 document trong collection `rooms`).
class Room {
  final String code;
  final String hostId;
  final RoomStatus status;
  final List<RoomPlayer> players;
  final int maxPlayers;

  /// Trạng thái ván chơi (null khi còn ở sảnh chờ).
  final GameState? game;

  const Room({
    required this.code,
    required this.hostId,
    required this.status,
    required this.players,
    required this.maxPlayers,
    this.game,
  });

  bool get isFull => players.length >= maxPlayers;

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'status': status.name,
    'players': players.map((p) => p.toJson()).toList(),
    'playerIds': players.map((p) => p.id).toList(),
    'maxPlayers': maxPlayers,
    'game': game?.toJson(),
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    code: json['code'] as String,
    hostId: json['hostId'] as String,
    status: RoomStatus.values.byName(json['status'] as String),
    players: (json['players'] as List)
        .map((e) => RoomPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    maxPlayers: (json['maxPlayers'] as int?) ?? 4,
    game: json['game'] == null
        ? null
        : GameState.fromJson(Map<String, dynamic>.from(json['game'] as Map)),
  );
}
