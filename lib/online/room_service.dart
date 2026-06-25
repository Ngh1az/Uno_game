import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../game/game_limits.dart';
import '../friends/active_room_tracker.dart';
import '../security/action_rate_limit.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import 'room.dart';

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
      if (room.isFull) {
        throw RoomException('Phòng đã đủ người.');
      }
      tx.update(ref, {
        'players': FieldValue.arrayUnion([
          RoomPlayer(
            id: id,
            name: name,
            photoUrl: profile.photoUrl,
            equippedTitleId: profile.equippedTitleId,
          ).toJson(),
        ]),
        'playerIds': FieldValue.arrayUnion([id]),
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
      final update = <String, dynamic>{
        'players': remaining.map((p) => p.toJson()).toList(),
        'playerIds': remaining.map((p) => p.id).toList(),
        if (room.hostId == id) 'hostId': remaining.first.id,
      };

      if (room.status == RoomStatus.playing && data['game'] != null) {
        final game = GameState.fromJson(
          Map<String, dynamic>.from(data['game'] as Map),
        );
        final idx = game.players.indexWhere((p) => p.id == id);
        if (idx >= 0) {
          game.players.removeAt(idx);
          if (game.players.isEmpty) {
            tx.delete(ref);
            return;
          }
          if (idx < game.currentPlayerIndex) {
            game.currentPlayerIndex--;
          } else if (game.currentPlayerIndex >= game.players.length) {
            game.currentPlayerIndex = 0;
          }
          game.log.add('${leaver.name} đã rời ván.');
          update['game'] = game.toJson();
          update['status'] = game.status == GameStatus.finished
              ? RoomStatus.finished.name
              : RoomStatus.playing.name;
        }
      }

      tx.update(ref, update);
    });
    await ActiveRoomTracker.instance.clear(id);
  }

  /// Host bắt đầu ván: chia bài và đẩy GameState lên Firestore.
  Future<void> startGame(String code) async {
    final id = uid;
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw RoomException('Phòng không tồn tại.');
      final room = Room.fromJson(snap.data()!);
      if (room.hostId != id) {
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
      action(game, id); // có thể ném InvalidMoveException
      tx.update(ref, {
        'game': game.toJson(),
        'status': game.status == GameStatus.finished
            ? RoomStatus.finished.name
            : RoomStatus.playing.name,
      });
    });
  }

  Future<void> playCard(
    String code,
    UnoCard card, {
    CardColor? chosenColor,
    int? handIndex,
    bool declaredUno = false,
  }) {
    return _mutateGame(code, (game, id) {
      game.playCard(
        id,
        card,
        chosenColor: chosenColor,
        handIndex: handIndex,
        declaredUno: declaredUno,
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
}
