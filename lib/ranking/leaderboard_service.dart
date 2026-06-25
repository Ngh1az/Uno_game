import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'leaderboard_entry.dart';

/// Tải bảng xếp hạng từ collection `users` trên Firestore.
class LeaderboardService {
  LeaderboardService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _limit = 50;

  Future<List<LeaderboardEntry>> fetch(LeaderboardMetric metric) async {
    try {
      final snap = await _db
          .collection('users')
          .orderBy(metric.field, descending: true)
          .limit(_limit)
          .get();

      return snap.docs
          .map((doc) => _fromDoc(doc, metric))
          .where((e) => e.value > 0)
          .toList();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('LeaderboardService.fetch failed: $e\n$stack');
      }
      rethrow;
    }
  }

  LeaderboardEntry _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    LeaderboardMetric metric,
  ) {
    final data = doc.data();
    final name = (data['displayName'] as String?)?.trim();
    return LeaderboardEntry(
      uid: doc.id,
      displayName: (name != null && name.isNotEmpty) ? name : 'Người chơi',
      photoUrl: data['photoUrl'] as String?,
      equippedTitleId: data['equippedTitle'] as String?,
      value: _readInt(data[metric.field]),
    );
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
