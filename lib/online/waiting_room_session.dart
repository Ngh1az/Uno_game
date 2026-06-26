import 'dart:async';

import 'package:flutter/foundation.dart';

import '../friends/active_room_tracker.dart';
import '../friends/friends_service.dart';
import '../navigation/app_navigator.dart';
import '../notifications/in_app_notifications.dart';
import '../game/game_limits.dart';
import 'online_game_controller.dart';

/// Phiên phòng chờ sống ngoài [RoomScreen] — cho phép về Home mà vẫn ở trong phòng.
class WaitingRoomSession extends ChangeNotifier {
  WaitingRoomSession._();

  static final WaitingRoomSession instance = WaitingRoomSession._();

  OnlineGameController? _controller;
  bool _minimized = false;
  bool _gameStartedWhileMinimized = false;
  bool _roomClosedNotified = false;
  bool _roomClosedWhileAway = false;
  bool _kickedWhileAway = false;
  bool _roomScreenVisible = false;
  bool _leavingVoluntarily = false;

  String? get roomCode => _controller?.code;

  int get playerCount => _controller?.room?.players.length ?? 0;

  int get maxPlayers =>
      _controller?.room?.maxPlayers ?? GameLimits.maxPlayers;

  OnlineGameController? get controller => _controller;

  bool get isActive => _controller != null;

  bool get isMinimized => _minimized;

  bool get isWaiting => _controller?.isWaiting ?? false;

  bool get isPlaying => _controller?.isPlaying ?? false;

  bool get roomScreenVisible => _roomScreenVisible;

  bool get shouldShowFloatingBanner =>
      isActive && isWaiting && _minimized;

  bool get gameStartedWhileMinimized => _gameStartedWhileMinimized;

  bool get roomClosedWhileAway => _roomClosedWhileAway;

  bool get kickedWhileAway => _kickedWhileAway;

  bool get leavingVoluntarily => _leavingVoluntarily;

  void clearKickedFlag() {
    if (!_kickedWhileAway) return;
    _kickedWhileAway = false;
    notifyListeners();
  }

  void clearGameStartedFlag() {
    if (!_gameStartedWhileMinimized) return;
    _gameStartedWhileMinimized = false;
    notifyListeners();
  }

  void clearRoomClosedFlag() {
    if (!_roomClosedWhileAway) return;
    _roomClosedWhileAway = false;
    notifyListeners();
  }

  void setRoomScreenVisible(bool visible) {
    if (_roomScreenVisible == visible) return;
    _roomScreenVisible = visible;
    notifyListeners();
  }

  /// Gọi trước khi mở lại [RoomScreen] (từ banner) để ẩn overlay ngay.
  void returnToRoomUi() {
    _minimized = false;
    _roomScreenVisible = true;
    notifyListeners();
  }

  /// Gắn hoặc tái sử dụng controller cho mã phòng.
  OnlineGameController bind(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError('room code is empty');
    }

    if (_controller != null && _controller!.code == normalized) {
      _minimized = false;
      _roomScreenVisible = true;
      _gameStartedWhileMinimized = false;
      _roomClosedWhileAway = false;
      _kickedWhileAway = false;
      notifyListeners();
      return _controller!;
    }

    _detachController(leaveFirestore: true);
    _controller = OnlineGameController(code: normalized)..start();
    _controller!.addListener(_onControllerChanged);
    _minimized = false;
    _roomScreenVisible = true;
    _gameStartedWhileMinimized = false;
    _roomClosedNotified = false;
    _roomClosedWhileAway = false;
    _kickedWhileAway = false;
    notifyListeners();
    return _controller!;
  }

  /// Dọn phiên cục bộ khi đã bị đuổi khỏi phòng (không gọi leave Firestore).
  Future<void> ejectLocal() async {
    final c = _controller;
    if (c == null) return;

    c.removeListener(_onControllerChanged);
    _controller = null;
    _minimized = false;
    _gameStartedWhileMinimized = false;
    _roomClosedNotified = false;
    _roomScreenVisible = false;
    notifyListeners();

    final uid = c.uid;
    await _finalizeController(c, uid: uid, leaveFirestore: false);
  }

  void minimize() {
    if (_controller == null) return;
    _minimized = true;
    notifyListeners();
  }

  Future<void> leave() async {
    final c = _controller;
    if (c == null) return;

    _leavingVoluntarily = true;
    notifyListeners();

    // Dọn UI state ngay (đồng bộ) để UX responsive.
    c.removeListener(_onControllerChanged);
    _controller = null;
    _minimized = false;
    _gameStartedWhileMinimized = false;
    _roomClosedNotified = false;
    _roomScreenVisible = false;
    notifyListeners();

    // Await Firestore leave — đảm bảo player bị xoá khỏi phòng trước khi return.
    final uid = c.uid;
    try {
      await _finalizeController(c, uid: uid, leaveFirestore: true);
    } finally {
      _leavingVoluntarily = false;
      notifyListeners();
    }
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c == null) return;

    if (c.roomClosed && !_roomClosedNotified) {
      _roomClosedNotified = true;
      final wasAway = _minimized;
      _detachController(leaveFirestore: false);
      if (wasAway) _roomClosedWhileAway = true;
      notifyListeners();
      return;
    }

    if (c.room != null && !c.isMember) {
      if (_leavingVoluntarily) return;
      if (_roomScreenVisible && !_minimized) {
        return;
      }
      final wasAway = _minimized || !_roomScreenVisible;
      _detachController(leaveFirestore: false);
      if (wasAway) _kickedWhileAway = true;
      notifyListeners();
      return;
    }

    if (_minimized && c.isPlaying && !_gameStartedWhileMinimized) {
      _gameStartedWhileMinimized = true;
    }

    if (_minimized && c.isPlaying && c.isMyTurn) {
      final game = c.game;
      final ctx = rootNavigatorKey.currentContext;
      if (game != null && ctx != null && ctx.mounted) {
        InAppNotifications.notifyMyTurn(
          ctx,
          turnKey: '${c.code}-${game.log.length}',
          message: 'Đến lượt bạn — vào phòng!',
        );
      }
    }

    unawaited(_syncActiveRoomStatus(c));
    if (c.isPlaying) {
      unawaited(FriendsService().dismissAllRoomInvites());
    }

    notifyListeners();
  }

  Future<void> _syncActiveRoomStatus(OnlineGameController c) async {
    final uid = c.uid;
    final room = c.room;
    if (uid.isEmpty || room == null) return;
    await ActiveRoomTracker.instance.updateRoomStatus(uid, room.code, room.status);
  }

  void _detachController({required bool leaveFirestore}) {
    final c = _controller;
    if (c == null) return;

    c.removeListener(_onControllerChanged);
    _controller = null;
    _minimized = false;
    _gameStartedWhileMinimized = false;
    _roomClosedNotified = false;
    _roomScreenVisible = false;

    final uid = c.uid;
    unawaited(_finalizeController(c, uid: uid, leaveFirestore: leaveFirestore));
  }

  Future<void> _finalizeController(
    OnlineGameController c, {
    required String uid,
    required bool leaveFirestore,
  }) async {
    Object? lastError;
    if (leaveFirestore) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await c.leave();
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (kDebugMode) {
            debugPrint('WaitingRoomSession.leave failed (attempt ${attempt + 1}): $e');
          }
        }
      }
    }
    if (uid.isNotEmpty) {
      await ActiveRoomTracker.instance.clear(uid);
    }
    c.dispose();
    if (lastError != null) throw lastError;
  }
}
