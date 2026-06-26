import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/auto_turn_player.dart';
import '../game/game_limits.dart';
import '../game/turn_timeout_policy.dart';
import '../friends/active_room_tracker.dart';
import '../security/action_rate_limit.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import 'room.dart';
import 'room_leave_logic.dart';

/// Lỗi thao tác phòng online.
class RoomException implements Exception {
  final String message;
  RoomException(this.message);
  @override
  String toString() => message;
}

/// Profile hiển thị trên chip khi vào phòng online.
class RoomPlayerProfile {
  const RoomPlayerProfile({this.photoUrl, this.equippedTitleId});

  final String? photoUrl;
  final String? equippedTitleId;
}

/// Dịch vụ quản lý phòng chơi online trên Cloud Firestore + Firebase Auth (ẩn danh).
class RoomService {
  RoomService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  /// Đăng nhập ẩn danh (nếu chưa) và trả về uid.
  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;

    final limited = await ActionRateLimit.tryGuestSignIn();
    if (limited != null) throw RoomException(limited);

    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  String get uid => _auth.currentUser?.uid ?? '';

  /// Tạo phòng mới, trả về mã phòng (6 ký tự).
  Future<String> createRoom({
    required String hostName,
    int maxPlayers = GameLimits.maxPlayers,
    RoomPlayerProfile profile = const RoomPlayerProfile(),
  }) async {
    final id = await ensureSignedIn();
    final limited = ActionRateLimit.forUid(
      'create_room',
      id,
      limit: 8,
      window: const Duration(minutes: 15),
    );
    if (limited != null) throw RoomException(limited);

    final code = await _generateUniqueCode();
    final room = Room(
      code: code,
      hostId: id,
      status: RoomStatus.waiting,
      players: [
        RoomPlayer(
          id: id,
          name: hostName,
          photoUrl: profile.photoUrl,
          equippedTitleId: profile.equippedTitleId,
        ),
      ],
      maxPlayers: maxPlayers,
    );
    await _rooms.doc(code).set({
      ...room.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ActiveRoomTracker.instance.setRoom(id, code);
    return code;
  }

  /// Vào phòng theo mã.
  Future<void> joinRoom({
    required String code,
    required String name,
    RoomPlayerProfile profile = const RoomPlayerProfile(),
  }) async {
    final id = await ensureSignedIn();
    final limited = ActionRateLimit.forUid(
      'join_room',
      id,
      limit: 20,
      window: const Duration(minutes: 15),
    );
    if (limited != null) throw RoomException(limited);

    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw RoomException('Không tìm thấy phòng "$code".');
      }
      final room = Room.fromJson(snap.data()!);
      final storedPlayerIds =
          (snap.data()!['playerIds'] as List?)?.cast<String>() ??
          room.players.map((p) => p.id).toList();
      if (room.status != RoomStatus.waiting) {
        throw RoomException('Phòng đã bắt đầu chơi.');
      }
      final existing = room.players.indexWhere((p) => p.id == id);
      if (existing >= 0) {
        final updated = [...room.players];
        updated[existing] = RoomPlayer(
          id: id,
          name: name,
          photoUrl: profile.photoUrl ?? updated[existing].photoUrl,
          equippedTitleId:
              profile.equippedTitleId ?? updated[existing].equippedTitleId,
        );
        tx.update(ref, {
          'players': updated.map((p) => p.toJson()).toList(),
        });
        return;
      }
      if (storedPlayerIds.contains(id)) {
        // Còn trong playerIds nhưng thiếu trong players — chỉ sync players.
        final newPlayer = RoomPlayer(
          id: id,
          name: name,
          photoUrl: profile.photoUrl,
          equippedTitleId: profile.equippedTitleId,
        );
        tx.update(ref, {
          'players': [...room.players, newPlayer].map((p) => p.toJson()).toList(),
        });
        return;
      }
      if (room.isFull) {
        throw RoomException('Phòng đã đủ người.');
      }
      final newPlayer = RoomPlayer(
        id: id,
        name: name,
        photoUrl: profile.photoUrl,
        equippedTitleId: profile.equippedTitleId,
      );
      tx.update(ref, {
        'players': [...room.players, newPlayer].map((p) => p.toJson()).toList(),
        'playerIds': [...storedPlayerIds, id],
      });
    });
    await ActiveRoomTracker.instance.setRoom(id, code);
  }

  /// Rời phòng. Nếu host rời và còn người khác, chuyển host. Nếu hết người, xoá phòng.
  Future<void> leaveRoom(String code) async {
    final id = uid;
    if (id.isEmpty) return;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = Room.fromJson(snap.data()!);
      final remaining = room.players.where((p) => p.id != id).toList();
      if (remaining.isEmpty) {
        tx.delete(ref);
        return;
      }
      final data = snap.data()!;
      final leaver = room.players.firstWhere((p) => p.id == id);
      final update = _roomMembersUpdate(room: room, remaining: remaining);

      if (room.status == RoomStatus.playing && data['game'] != null) {
        final game = GameState.fromJson(
          Map<String, dynamic>.from(data['game'] as Map),
        );
        final finished = forfeitPlayerInGame(
          game: game,
          playerId: id,
          playerName: leaver.name,
          reason: 'đã rời ván',
        );
        if (game.players.isEmpty) {
          tx.delete(ref);
          return;
        }
        update['game'] = game.toJson();
        update['status'] = game.status == GameStatus.finished
            ? RoomStatus.finished.name
            : RoomStatus.playing.name;
        if (!finished) {
          update['turnStartedAt'] = FieldValue.serverTimestamp();
        }
      }

      tx.update(ref, update);
    });
    await ActiveRoomTracker.instance.clear(id);
  }

  /// Chủ phòng đuổi người chơi khỏi phòng (sảnh chờ hoặc đang chơi).
  Future<void> kickPlayer(String code, String targetId) async {
    final id = uid;
    if (id.isEmpty || targetId.isEmpty || targetId == id) {
      throw RoomException('Không thể đuổi người chơi này.');
    }
    final limited = ActionRateLimit.forUid(
      'kick_player',
      id,
      limit: 12,
      window: const Duration(minutes: 15),
    );
    if (limited != null) throw RoomException(limited);

    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw RoomException('Phòng không tồn tại.');
      final room = Room.fromJson(snap.data()!);
      if (!_isActingHost(room, id)) {
        throw RoomException('Chỉ chủ phòng mới được đuổi người chơi.');
      }
      final target = _findPlayer(room.players, targetId);
      if (target == null) {
        throw RoomException('Người chơi không còn trong phòng.');
      }

      final remaining = room.players.where((p) => p.id != targetId).toList();
      final data = snap.data()!;
      final update = _roomMembersUpdate(room: room, remaining: remaining);
      if (!update.containsKey('hostId')) {
        final repairedHost = resolveHostIdAfterRemoval(
          currentHostId: room.hostId,
          remainingMemberIdsInOrder: room.players.map((p) => p.id).toList(),
        );
        if (repairedHost != room.hostId) {
          update['hostId'] = repairedHost;
        }
      }

      if (room.status == RoomStatus.playing && data['game'] != null) {
        final game = GameState.fromJson(
          Map<String, dynamic>.from(data['game'] as Map),
        );
        final memberIds = remaining.map((p) => p.id).toSet();
        if (game.players.any((p) => p.id == targetId)) {
          forfeitPlayerInGame(
            game: game,
            playerId: targetId,
            playerName: target.name,
            reason: 'bị chủ phòng đuổi',
          );
        } else {
          game.log.add('${target.name} bị chủ phòng đuổi.');
        }
        syncGamePlayersWithMembers(game: game, memberIds: memberIds);
        if (game.players.length == 1 && game.status == GameStatus.playing) {
          final winner = game.players.first;
          game.status = GameStatus.finished;
          game.winnerId = winner.id;
          game.log.add('${winner.name} THẮNG!');
        }
        update['game'] = game.toJson();
        update['status'] = game.status == GameStatus.finished
            ? RoomStatus.finished.name
            : RoomStatus.playing.name;
        if (game.status == GameStatus.playing) {
          update['turnStartedAt'] = FieldValue.serverTimestamp();
        }
      }

      tx.update(ref, update);
    });
    await ActiveRoomTracker.instance.clear(targetId);
  }

  /// Hết giờ lượt — tự động đánh; đủ 3 lần thì coi như rời ván.
  Future<void> enforceTurnTimeout(String code, {bool autoUno = true}) async {
    final id = uid;
    if (id.isEmpty) return;
    final ref = _rooms.doc(code);
    var forfeitUid = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != RoomStatus.playing.name) return;
      if (!_isTurnExpired(data)) return;

      final room = Room.fromJson(data);
      if (room.game == null || room.game!.status != GameStatus.playing) return;

      final game = GameState.fromJson(
        Map<String, dynamic>.from(data['game'] as Map),
      );
      final timedOutId = game.currentPlayer.id;
      final timedOutName = game.currentPlayer.name;

      game.log.add('$timedOutName hết giờ — tự động đánh.');
      AutoTurnPlayer.takeTurn(game, autoUno: autoUno);
      game.incrementTimeoutStrike(timedOutId);

      final update = <String, dynamic>{
        'turnStartedAt': FieldValue.serverTimestamp(),
      };

      if (game.timeoutStrikeCount(timedOutId) >= TurnTimeoutPolicy.maxStrikes &&
          game.status == GameStatus.playing) {
        forfeitUid = timedOutId;
        _applyForfeitToUpdate(
          update: update,
          room: room,
          game: game,
          playerId: timedOutId,
          playerName: timedOutName,
          reason: 'treo máy quá lâu',
        );
      } else {
        update['game'] = game.toJson();
        update['status'] = game.status == GameStatus.finished
            ? RoomStatus.finished.name
            : RoomStatus.playing.name;
      }

      tx.update(ref, update);
    });
    if (forfeitUid.isNotEmpty) {
      await ActiveRoomTracker.instance.clear(forfeitUid);
    }
  }

  /// Người đang lượt offline quá lâu — coi như rời ván ngay.
  Future<void> enforceAfkForfeit(String code, String targetId) async {
    final id = uid;
    if (id.isEmpty || targetId.isEmpty) return;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != RoomStatus.playing.name) return;

      final room = Room.fromJson(data);
      if (room.game == null || room.game!.status != GameStatus.playing) return;
      if (room.game!.currentPlayer.id != targetId) return;

      final game = GameState.fromJson(
        Map<String, dynamic>.from(data['game'] as Map),
      );
      final target = _findPlayer(room.players, targetId);
      if (target == null) return;

      final update = <String, dynamic>{
        'turnStartedAt': FieldValue.serverTimestamp(),
      };
      _applyForfeitToUpdate(
        update: update,
        room: room,
        game: game,
        playerId: targetId,
        playerName: target.name,
        reason: 'mất kết nối quá lâu',
      );
      tx.update(ref, update);
    });
    await ActiveRoomTracker.instance.clear(targetId);
  }

  /// Host bắt đầu ván: chia bài và đẩy GameState lên Firestore.
  Future<void> startGame(String code) async {
    final id = uid;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw RoomException('Phòng không tồn tại.');
      final room = Room.fromJson(snap.data()!);
      if (!_isActingHost(room, id)) {
        throw RoomException('Chỉ chủ phòng mới được bắt đầu.');
      }
      if (room.players.length < 2) {
        throw RoomException('Cần ít nhất 2 người để bắt đầu.');
      }
      final players = room.players
          .map((p) => UnoPlayer(id: p.id, name: p.name))
          .toList();
      final game = GameState.newGame(players: players);
      tx.update(ref, {
        'status': RoomStatus.playing.name,
        'game': game.toJson(),
        'turnStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Lắng nghe realtime một phòng.
  Stream<Room?> watchRoom(String code) {
    return _rooms.doc(code).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Room.fromJson(snap.data()!);
    });
  }

  /// Áp dụng một nước đi lên GameState rồi ghi lại (dùng transaction để tránh tranh chấp).
  Future<void> _mutateGame(
    String code,
    void Function(GameState game, String uid) action,
  ) async {
    final id = uid;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw RoomException('Phòng không tồn tại.');
      final data = snap.data()!;
      if (data['game'] == null) throw RoomException('Ván chưa bắt đầu.');
      final game = GameState.fromJson(Map<String, dynamic>.from(data['game'] as Map));
      action(game, id);
      game.resetTimeoutStrike(id);
      final finished = game.status == GameStatus.finished;
      tx.update(ref, {
        'game': game.toJson(),
        'status': finished ? RoomStatus.finished.name : RoomStatus.playing.name,
        if (!finished) 'turnStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool _isTurnExpired(Map<String, dynamic> data) {
    final ts = data['turnStartedAt'];
    if (ts is! Timestamp) return false;
    return DateTime.now().difference(ts.toDate()) >= TurnTimeoutPolicy.turnDuration;
  }

  void _applyForfeitToUpdate({
    required Map<String, dynamic> update,
    required Room room,
    required GameState game,
    required String playerId,
    required String playerName,
    required String reason,
  }) {
    forfeitPlayerInGame(
      game: game,
      playerId: playerId,
      playerName: playerName,
      reason: reason,
    );
    final remaining = room.players.where((p) => p.id != playerId).toList();
    update.addAll(_roomMembersUpdate(room: room, remaining: remaining));
    update['game'] = game.toJson();
    update['status'] = game.status == GameStatus.finished
        ? RoomStatus.finished.name
        : RoomStatus.playing.name;
  }

  Future<void> playCard(
    String code,
    UnoCard card, {
    CardColor? chosenColor,
    int? handIndex,
    bool declaredUno = false,
    bool autoUno = false,
  }) {
    return _mutateGame(code, (game, id) {
      game.playCard(
        id,
        card,
        chosenColor: chosenColor,
        handIndex: handIndex,
        declaredUno: declaredUno,
        autoUno: autoUno,
      );
    });
  }

  Future<void> drawCard(String code) {
    return _mutateGame(code, (game, id) => game.drawCard(id));
  }

  Future<void> endTurn(String code) {
    return _mutateGame(code, (game, id) => game.endTurn(id));
  }

  Future<void> callUno(String code) {
    return _mutateGame(code, (game, id) => game.callUno(id));
  }

  Future<void> catchUno(String code, String targetId) {
    return _mutateGame(code, (game, id) => game.catchUno(id, targetId));
  }

  Future<void> acceptDrawStack(String code) {
    return _mutateGame(code, (game, id) => game.acceptDrawStack(id));
  }

  /// Sinh mã phòng 6 ký tự chưa bị trùng.
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ ký tự dễ nhầm
    final rng = Random.secure();
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = List.generate(
        6,
        (_) => chars[rng.nextInt(chars.length)],
      ).join();
      final snap = await _rooms.doc(code).get();
      if (!snap.exists) return code;
    }
    throw RoomException('Không tạo được mã phòng, thử lại.');
  }

  RoomPlayer? _findPlayer(List<RoomPlayer> players, String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> _roomMembersUpdate({
    required Room room,
    required List<RoomPlayer> remaining,
  }) {
    final memberIds = remaining.map((p) => p.id).toList();
    final nextHost = resolveHostIdAfterRemoval(
      currentHostId: room.hostId,
      remainingMemberIdsInOrder: memberIds,
    );
    return {
      'players': remaining.map((p) => p.toJson()).toList(),
      'playerIds': memberIds,
      if (nextHost != room.hostId) 'hostId': nextHost,
    };
  }

  bool _isActingHost(Room room, String uid) {
    if (room.hostId == uid) return true;
    if (room.players.isEmpty) return false;
    if (room.players.any((p) => p.id == room.hostId)) return false;
    return room.players.first.id == uid;
  }

  /// Sửa hostId mồ côi (host đã rời nhưng hostId chưa đổi).
  Future<void> repairGhostHost(String code) async {
    final id = uid;
    if (id.isEmpty) return;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = Room.fromJson(snap.data()!);
      if (room.players.isEmpty) return;
      if (room.players.any((p) => p.id == room.hostId)) return;

      final nextHost = resolveHostIdAfterRemoval(
        currentHostId: room.hostId,
        remainingMemberIdsInOrder: room.players.map((p) => p.id).toList(),
      );
      if (nextHost == room.hostId) return;
      tx.update(ref, {'hostId': nextHost});
    });
  }
}
