import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Cập nhật trạng thái online qua `isOnline` + `lastActiveAt` trên Firestore.
class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  factory PresenceService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _timer;
  String? _uid;

  static const _heartbeat = Duration(seconds: 60);
  static const onlineThreshold = Duration(minutes: 2);

  static bool isOnline(DateTime? lastActiveAt, {bool? onlineFlag}) {
    if (onlineFlag == false) return false;
    if (lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt) < onlineThreshold;
  }

  Future<void> start(String uid) async {
    if (uid.isEmpty) return;
    _uid = uid;
    await _setOnline(true);
    _timer?.cancel();
    _timer = Timer.periodic(_heartbeat, (_) => _setOnline(true));
  }

  /// Dừng heartbeat và đánh dấu offline trên server.
  Future<void> goOffline() async {
    _timer?.cancel();
    _timer = null;
    final uid = _uid;
    _uid = null;
    if (uid == null || uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set(
        {
          'isOnline': false,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('PresenceService.goOffline failed: $e');
    }
  }

  void stop() {
    unawaited(goOffline());
  }

  Future<void> _setOnline(bool online) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set(
        {
          'isOnline': online,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('PresenceService._setOnline failed: $e');
    }
  }
}
