import 'dart:async';

import 'package:flutter/foundation.dart';

import '../friends/active_room_tracker.dart';
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
  bool _roomScreenVisible = false;

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
    notifyListeners();
    return _controller!;
  }

  void minimize() {
    if (_controller == null) return;
    _minimized = true;
    notifyListeners();
  }

  Future<void> leave() async {
    _detachController(leaveFirestore: true);
    notifyListeners();
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

    if (_minimized && c.isPlaying && !_gameStartedWhileMinimized) {
      _gameStartedWhileMinimized = true;
    }

    notifyListeners();
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
    if (leaveFirestore) {
      try {
        await c.leave();
      } catch (e) {
        if (kDebugMode) debugPrint('WaitingRoomSession.leave failed: $e');
      }
    }
    if (uid.isNotEmpty) {
      await ActiveRoomTracker.instance.clear(uid);
    }
    c.dispose();
  }
}
