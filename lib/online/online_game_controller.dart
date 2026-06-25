import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
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

  Room? get room => _room;
  String? get error => _error;
  String get uid => _service.uid;

  bool get roomClosed => _sub != null && _room == null;

  GameState? get game => _room?.game;
  bool get isPlaying => _room?.status == RoomStatus.playing;
  bool get isFinished => _room?.status == RoomStatus.finished;
  bool get isWaiting => _room?.status == RoomStatus.waiting;
  bool get isHost => _room != null && _room!.hostId == uid;

  UnoPlayer? get me =>
      game?.players.firstWhere((p) => p.id == uid, orElse: () => game!.players.first);

  bool get isMyTurn =>
      isPlaying && game != null && game!.currentPlayer.id == uid;

  bool get canPass => isMyTurn && game!.drawnThisTurn;

  /// Bắt đầu lắng nghe phòng.
  void start() {
    _sub = _service.watchRoom(code).listen((room) {
      _room = room;
      notifyListeners();
    });
  }

  bool canPlay(UnoCard card) =>
      isMyTurn && game != null && game!.canPlay(card);

  Future<void> startGame() => _guard(() => _service.startGame(code));

  Future<void> playCard(
    UnoCard card, {
    CardColor? chosenColor,
    int? handIndex,
    bool declaredUno = false,
  }) =>
      _guard(() => _service.playCard(
            code,
            card,
            chosenColor: chosenColor,
            handIndex: handIndex,
            declaredUno: declaredUno,
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
