import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../friends/friends_service.dart';
import '../security/action_rate_limit.dart';
import '../daily_quests/daily_quest_store.dart';
import '../titles/title_store.dart';

/// Đồng bộ xu + danh hiệu lên Firestore theo uid Google (web ↔ mobile).
class CloudProgressService {
  CloudProgressService._();

  static final CloudProgressService instance = CloudProgressService._();

  static const _collection = 'users';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Gộp dữ liệu local với cloud sau khi đăng nhập Google.
  Future<void> sync(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) async {
    if (uid.isEmpty) return;

    try {
      final ref = _db.collection(_collection).doc(uid);
      final snap = await ref.get();
      final cloud = snap.exists ? snap.data()! : const <String, dynamic>{};

      final quest = DailyQuestStore.instance;
      final titles = TitleStore.instance;

      final localCoins = quest.coins;
      final cloudCoins = _readInt(cloud['coins']);
      final mergedCoins = ProgressBounds.clampCoins(
        localCoins > cloudCoins ? localCoins : cloudCoins,
      );

      if (mergedCoins != localCoins) {
        quest.coins = mergedCoins;
        await quest.persistCoins();
        quest.notifyListeners();
      }

      _mergeTitleStats(titles, cloud);
      while (titles.unlockedIds.length > ProgressBounds.maxUnlockedTitles) {
        titles.unlockedIds.remove(titles.unlockedIds.first);
      }
      await titles.persistFromCloudMerge();

      final payload = <String, dynamic>{
        'coins': mergedCoins,
        'gamesPlayed': ProgressBounds.clampStat(titles.gamesPlayed),
        'offlineWins': ProgressBounds.clampStat(titles.offlineWins),
        'onlineJoins': ProgressBounds.clampStat(titles.onlineJoins),
        'onlineWins': ProgressBounds.clampStat(titles.onlineWins),
        'unlockedTitles': titles.unlockedIds.toList(),
        'seenUnlocks': titles.seenUnlockIds.take(64).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        payload['displayName'] = name;
      }
      final avatar = photoUrl?.trim();
      if (avatar != null && avatar.isNotEmpty) {
        payload['photoUrl'] = avatar;
      }
      final equipped = titles.equippedId;
      if (equipped != null) {
        payload['equippedTitle'] = equipped;
      }

      await ref.set(payload, SetOptions(merge: true));
      try {
        await FriendsService().ensureFriendCode(uid);
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('CloudProgressService.ensureFriendCode failed: $e\n$stack');
        }
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('CloudProgressService.sync failed: $e\n$stack');
      }
    }
  }

  Future<void> pushCoins(String uid, int coins) async {
    if (uid.isEmpty) return;
    final safe = ProgressBounds.clampCoins(coins);
    try {
      await _db.collection(_collection).doc(uid).set(
        {
          'coins': safe,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CloudProgressService.pushCoins failed: $e');
    }
  }

  Future<void> pushTitles(String uid) async {
    if (uid.isEmpty) return;
    final titles = TitleStore.instance;
    try {
      final payload = <String, dynamic>{
        'gamesPlayed': ProgressBounds.clampStat(titles.gamesPlayed),
        'offlineWins': ProgressBounds.clampStat(titles.offlineWins),
        'onlineJoins': ProgressBounds.clampStat(titles.onlineJoins),
        'onlineWins': ProgressBounds.clampStat(titles.onlineWins),
        'unlockedTitles': ProgressBounds.clampUnlocked(titles.unlockedIds).toList(),
        'seenUnlocks': titles.seenUnlockIds.take(64).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final equipped = titles.equippedId;
      if (equipped != null) {
        payload['equippedTitle'] = equipped;
      } else {
        payload['equippedTitle'] = FieldValue.delete();
      }
      await _db.collection(_collection).doc(uid).set(
        payload,
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CloudProgressService.pushTitles failed: $e');
    }
  }

  void _mergeTitleStats(TitleStore titles, Map<String, dynamic> cloud) {
    titles.gamesPlayed = ProgressBounds.mergeStat(
      titles.gamesPlayed,
      _readInt(cloud['gamesPlayed']),
    );
    titles.offlineWins = ProgressBounds.mergeStat(
      titles.offlineWins,
      _readInt(cloud['offlineWins']),
      maxDelta: 5,
    );
    titles.onlineJoins = ProgressBounds.mergeStat(
      titles.onlineJoins,
      _readInt(cloud['onlineJoins']),
      maxDelta: 10,
    );
    titles.onlineWins = ProgressBounds.mergeStat(
      titles.onlineWins,
      _readInt(cloud['onlineWins']),
      maxDelta: 5,
    );

    titles.unlockedIds.addAll(_readStringList(cloud['unlockedTitles']));
    titles.seenUnlockIds.addAll(_readStringList(cloud['seenUnlocks']));

    final cloudEquipped = cloud['equippedTitle'];
    if (titles.equippedId == null &&
        cloudEquipped is String &&
        titles.unlockedIds.contains(cloudEquipped)) {
      titles.equippedId = cloudEquipped;
    }
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Set<String> _readStringList(Object? value) {
    if (value is! List) return {};
    return value.whereType<String>().toSet();
  }
}
