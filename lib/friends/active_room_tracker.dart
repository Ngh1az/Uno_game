import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../online/room.dart';

/// Theo dõi phòng đang ở (mời bạn / trạng thái online).
class ActiveRoomTracker extends ChangeNotifier {
  ActiveRoomTracker._();

  static final ActiveRoomTracker instance = ActiveRoomTracker._();

  String? _roomCode;
  String? _uid;

  String? get roomCode => _roomCode;

  bool get hasRoom => _roomCode != null && _roomCode!.isNotEmpty;

  Future<void> setRoom(
    String uid,
    String code, {
    RoomStatus status = RoomStatus.waiting,
  }) async {
    _uid = uid;
    _roomCode = code;
    notifyListeners();
    if (uid.isEmpty || code.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'activeRoomCode': code,
          'activeRoomStatus': status.name,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ActiveRoomTracker.setRoom failed: $e');
    }
  }

  Future<void> updateRoomStatus(
    String uid,
    String code,
    RoomStatus status,
  ) async {
    if (uid.isEmpty || code.isEmpty) return;
    _uid = uid;
    _roomCode = code;
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'activeRoomCode': code,
          'activeRoomStatus': status.name,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ActiveRoomTracker.updateRoomStatus failed: $e');
    }
  }

  Future<void> clear(String uid) async {
    _roomCode = null;
    _uid = uid;
    notifyListeners();
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'activeRoomCode': FieldValue.delete(),
          'activeRoomStatus': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ActiveRoomTracker.clear failed: $e');
    }
  }

  void syncFromMemory(String uid) {
    if (_uid == uid && _roomCode != null) {
      setRoom(uid, _roomCode!);
    }
  }
}
