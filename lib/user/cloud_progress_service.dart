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

  /// Firestore rules chỉ cho tăng tối đa 500 xu mỗi lần ghi.
  static const _maxCoinsDeltaPerWrite = 500;

  /// Khớp validProgressDelta trong firestore.rules.
  static const _maxGamesPlayedDelta = 15;
  static const _maxOfflineWinsDelta = 5;
  static const _maxOnlineJoinsDelta = 10;
  static const _maxOnlineWinsDelta = 5;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Gộp dữ liệu local với cloud sau khi đăng nhập Google.
  /// Trả về `true` nếu sync thành công, `false` nếu có lỗi (mạng / quyền).
  Future<bool> sync(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) async {
    if (uid.isEmpty) return false;

    try {
      final ref = _db.collection(_collection).doc(uid);
      final snap = await ref.get();
      final cloud = snap.exists ? snap.data()! : const <String, dynamic>{};

      final quest = DailyQuestStore.instance;
      final titles = TitleStore.instance;

      // Xu: lấy max(local, cloud) để không bao giờ mất xu của người chơi.
      final localCoins = quest.coins;
      final cloudCoins = _readInt(cloud['coins']);
      final mergedCoins = ProgressBounds.clampCoins(
        localCoins > cloudCoins ? localCoins : cloudCoins,
      );
      await quest.applyCloudCoins(mergedCoins);

      // Nhiệm vụ ngày/tuần: gộp an toàn (max progress, OR claimed).
      final cloudQuests = cloud['quests'];
      if (cloudQuests is Map) {
        await quest.mergeCloudQuests(Map<String, dynamic>.from(cloudQuests));
      }

      _mergeTitleStats(titles, cloud);
      while (titles.unlockedIds.length > ProgressBounds.maxUnlockedTitles) {
        titles.unlockedIds.remove(titles.unlockedIds.first);
      }
      await titles.persistFromCloudMerge();

      // Xu + stats đẩy riêng (chunked) — tránh rules từ chối khi nhảy lớn.
      await pushCoins(uid, mergedCoins);
      await pushTitles(uid);

      final payload = <String, dynamic>{
        'quests': quest.questCloudPayload(),
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
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('CloudProgressService.sync failed: $e\n$stack');
      }
      return false;
    }
  }

  /// Đẩy snapshot nhiệm vụ ngày/tuần lên cloud (gọi sau khi quest thay đổi).
  Future<void> pushQuests(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection(_collection).doc(uid).set(
        {
          'quests': DailyQuestStore.instance.questCloudPayload(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CloudProgressService.pushQuests failed: $e');
    }
  }

  /// Đẩy số xu lên cloud. Tăng theo từng bước ≤500 để qua Firestore rules.
  Future<void> pushCoins(String uid, int coins) async {
    if (uid.isEmpty) return;
    final target = ProgressBounds.clampCoins(coins);
    final ref = _db.collection(_collection).doc(uid);

    try {
      while (true) {
        final snap = await ref.get();
        final current = snap.exists ? _readInt(snap.data()?['coins']) : 0;

        if (current == target) return;

        if (current > target) {
          await ref.set(
            {
              'coins': target,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          return;
        }

        final step = (target - current).clamp(1, _maxCoinsDeltaPerWrite);
        final next = current + step;
        await ref.set(
          {
            'coins': next,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (next >= target) return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CloudProgressService.pushCoins failed: $e');
    }
  }

  Future<void> pushTitles(String uid) async {
    if (uid.isEmpty) return;
    final titles = TitleStore.instance;
    final ref = _db.collection(_collection).doc(uid);

    try {
      await _pushStatField(
        ref,
        'gamesPlayed',
        titles.gamesPlayed,
        _maxGamesPlayedDelta,
      );
      await _pushStatField(
        ref,
        'offlineWins',
        titles.offlineWins,
        _maxOfflineWinsDelta,
      );
      await _pushStatField(
        ref,
        'onlineJoins',
        titles.onlineJoins,
        _maxOnlineJoinsDelta,
      );
      await _pushStatField(
        ref,
        'onlineWins',
        titles.onlineWins,
        _maxOnlineWinsDelta,
      );

      final payload = <String, dynamic>{
        'unlockedTitles':
            ProgressBounds.clampUnlocked(titles.unlockedIds).toList(),
        'seenUnlocks': titles.seenUnlockIds.take(64).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final equipped = titles.equippedId;
      if (equipped != null) {
        payload['equippedTitle'] = equipped;
      } else {
        payload['equippedTitle'] = FieldValue.delete();
      }
      await ref.set(payload, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('CloudProgressService.pushTitles failed: $e');
    }
  }

  /// Tăng một stat lên [target] theo từng bước ≤ [maxStep] (khớp Firestore rules).
  Future<void> _pushStatField(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    int target,
    int maxStep,
  ) async {
    final safeTarget = ProgressBounds.clampStat(target);
    while (true) {
      final snap = await ref.get();
      final current = snap.exists ? _readInt(snap.data()?[field]) : 0;
      final step = ProgressBounds.statChunkStep(current, safeTarget, maxStep);
      if (step == 0) return;

      final next = current + step;
      await ref.set(
        {
          field: next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (next >= safeTarget) return;
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
