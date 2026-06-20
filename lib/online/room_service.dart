import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  String get uid => _auth.currentUser?.uid ?? '';

  /// Tạo phòng mới, trả về mã phòng (6 ký tự).
  Future<String> createRoom({
    required String hostName,
    int maxPlayers = 4,
  }) async {
    final id = await ensureSignedIn();
    final code = await _generateUniqueCode();
    final room = Room(
      code: code,
      hostId: id,
      status: RoomStatus.waiting,
      players: [RoomPlayer(id: id, name: hostName)],
      maxPlayers: maxPlayers,
    );
    await _rooms.doc(code).set({
      ...room.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Vào phòng theo mã.
  Future<void> joinRoom({required String code, required String name}) async {
    final id = await ensureSignedIn();
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
      // Đã ở trong phòng -> bỏ qua.
      if (room.players.any((p) => p.id == id)) return;
      if (room.isFull) {
        throw RoomException('Phòng đã đủ người.');
      }
      tx.update(ref, {
        'players': FieldValue.arrayUnion([
          RoomPlayer(id: id, name: name).toJson(),
        ]),
        'playerIds': FieldValue.arrayUnion([id]),
      });
    });
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
      tx.update(ref, {
        'players': remaining.map((p) => p.toJson()).toList(),
        'playerIds': remaining.map((p) => p.id).toList(),
        if (room.hostId == id) 'hostId': remaining.first.id,
      });
    });
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

  Future<void> playCard(String code, UnoCard card, {CardColor? chosenColor}) {
    return _mutateGame(code, (game, id) {
      game.playCard(id, card, chosenColor: chosenColor);
    });
  }

  Future<void> drawCard(String code) {
    return _mutateGame(code, (game, id) => game.drawCard(id));
  }

  Future<void> endTurn(String code) {
    return _mutateGame(code, (game, id) => game.endTurn(id));
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
