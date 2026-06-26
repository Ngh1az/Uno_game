import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app_settings.dart';
import '../friends/presence_service.dart';
import '../game/turn_timeout_policy.dart';
import '../models/game_state.dart';
import 'online_game_controller.dart';

/// Theo dõi timeout lượt + AFK và kích hoạt xử lý trên Firestore.
class TurnTimeoutWatcher {
  TurnTimeoutWatcher({required this._controller});

  final OnlineGameController _controller;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _timer;
  bool _enforcing = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(TurnTimeoutPolicy.watcherInterval, (_) {
      unawaited(_tick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  Future<void> _tick() async {
    if (_enforcing) return;
    final room = _controller.room;
    final game = _controller.game;
    if (room == null || game == null || !_controller.isPlaying) return;
    if (game.status != GameStatus.playing) return;

    final started = room.turnStartedAt;
    if (started == null) return;

    final currentId = game.currentPlayer.id;
    final elapsed = DateTime.now().difference(started);

    if (await _shouldAfkForfeit(currentId, elapsed)) {
      _enforcing = true;
      try {
        await _controller.enforceAfkForfeit(currentId);
      } catch (e) {
        if (kDebugMode) debugPrint('TurnTimeoutWatcher AFK: $e');
      } finally {
        _enforcing = false;
      }
      return;
    }

    if (elapsed < TurnTimeoutPolicy.turnDuration) return;

    _enforcing = true;
    try {
      await _controller.enforceTurnTimeout(
        autoUno: AppSettings.instance.autoUnoCall,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('TurnTimeoutWatcher timeout: $e');
    } finally {
      _enforcing = false;
    }
  }

  Future<bool> _shouldAfkForfeit(String uid, Duration elapsed) async {
    if (elapsed < const Duration(seconds: 30)) return false;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return false;
      final data = snap.data()!;
      final online = data['isOnline'] as bool?;
      final ts = data['lastActiveAt'];
      final lastActive = ts is Timestamp ? ts.toDate() : null;
      return !PresenceService.isOnline(lastActive, onlineFlag: online);
    } catch (_) {
      return false;
    }
  }
}
