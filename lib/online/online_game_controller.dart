import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import '../game/turn_timeout_policy.dart';
import 'room.dart';
import 'room_service.dart';

/// Theo dõi một phòng online và cung cấp thao tác cho UI.
class OnlineGameController extends ChangeNotifier {
  OnlineGameController({required this.code, RoomService? service})
    : _service = service ?? RoomService();

  final String code;
  final RoomService _service;

  StreamSubscription<Room?>? _sub;
  Room? _room;
  String? _error;
  bool _ghostHostRepairAttempted = false;

  Room? get room => _room;
  String? get error => _error;
  String get uid => _service.uid;

  bool get roomClosed => _sub != null && _room == null;

  GameState? get game => _room?.game;
  bool get isPlaying => _room?.status == RoomStatus.playing;
  bool get isFinished => _room?.status == RoomStatus.finished;
  bool get isWaiting => _room?.status == RoomStatus.waiting;
  bool get isHost {
    final room = _room;
    if (room == null || uid.isEmpty) return false;
    if (room.hostId == uid) return true;
    // Host đã rời nhưng hostId chưa được cập nhật trên Firestore.
    if (room.players.isNotEmpty &&
        !room.players.any((p) => p.id == room.hostId)) {
      return room.players.first.id == uid;
    }
    return false;
  }

  bool get isMember =>
      _room != null && _room!.players.any((p) => p.id == uid);

  UnoPlayer? get me {
    final g = game;
    if (g == null || uid.isEmpty) return null;
    for (final p in g.players) {
      if (p.id == uid) return p;
    }
    return null;
  }

  bool get isMyTurn =>
      isPlaying && game != null && game!.currentPlayer.id == uid;

  bool get canPass => isMyTurn && game!.drawnThisTurn;

  /// Bắt đầu lắng nghe phòng.
  void start() {
    _ghostHostRepairAttempted = false;
    _sub = _service.watchRoom(code).listen((room) {
      _room = room;
      if (room != null &&
          _hasGhostHost(room) &&
          !_ghostHostRepairAttempted) {
        _ghostHostRepairAttempted = true;
        unawaited(_repairGhostHostSafe());
      }
      notifyListeners();
    });
  }

  Future<void> _repairGhostHostSafe() async {
    try {
      await _service.repairGhostHost(code);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('repairGhostHost failed for $code: $e');
      }
    }
  }

  bool _hasGhostHost(Room room) =>
      room.players.isNotEmpty &&
      !room.players.any((p) => p.id == room.hostId);

  bool canPlay(UnoCard card) =>
      isMyTurn && game != null && game!.canPlay(card);

  Future<void> startGame() => _guard(() => _service.startGame(code));

  Future<void> playCard(
    UnoCard card, {
    CardColor? chosenColor,
    int? handIndex,
    bool declaredUno = false,
    bool autoUno = false,
  }) =>
      _guard(() => _service.playCard(
            code,
            card,
            chosenColor: chosenColor,
            handIndex: handIndex,
            declaredUno: declaredUno,
            autoUno: autoUno,
          ));

  Future<void> drawCard() => _guard(() => _service.drawCard(code));

  Future<void> passTurn() => _guard(() => _service.endTurn(code));

  Future<void> callUno() => _guard(() => _service.callUno(code));

  Future<void> catchUno(String targetId) =>
      _guard(() => _service.catchUno(code, targetId));

  Future<void> acceptDrawStack() =>
      _guard(() => _service.acceptDrawStack(code));

  Future<void> leave() async {
    await _service.leaveRoom(code);
  }

  Future<void> kickPlayer(String targetId) async {
    try {
      _error = null;
      await _service.kickPlayer(code, targetId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> enforceTurnTimeout({bool autoUno = true}) =>
      _guard(() => _service.enforceTurnTimeout(code, autoUno: autoUno));

  Future<void> enforceAfkForfeit(String targetId) =>
      _guard(() => _service.enforceAfkForfeit(code, targetId));

  Duration? get turnTimeRemaining {
    final started = _room?.turnStartedAt;
    if (started == null || !isPlaying) return null;
    final remaining = TurnTimeoutPolicy.turnDuration -
        DateTime.now().difference(started);
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  int timeoutStrikesFor(String playerId) =>
      game?.timeoutStrikeCount(playerId) ?? 0;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      _error = null;
      await action();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
