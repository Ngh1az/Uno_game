import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../daily_quests/daily_quest_store.dart';
import '../user/user_session.dart';
import 'title_definition.dart';

/// Email được cấp toàn bộ danh hiệu (dev / admin).
const kFullTitleGrantEmails = <String>{
  'huynhhnghia991@gmail.com',
};

/// Thống kê + danh hiệu đã mở / đang đeo — lưu theo uid trên máy.
class TitleStore extends ChangeNotifier {
  TitleStore._();

  static final TitleStore instance = TitleStore._();

  String _uid = '';
  bool _loaded = false;

  int gamesPlayed = 0;
  int offlineWins = 0;
  int onlineJoins = 0;
  int onlineWins = 0;

  final Set<String> unlockedIds = {};
  String? equippedId;
  final Set<String> _seenUnlockIds = {};

  bool get _canWrite => _loaded && UserSession.isActiveUid(_uid);

  /// Gỡ cache RAM khi đổi / đăng xuất tài khoản.
  void unbind() {
    _loaded = false;
    _uid = '';
    gamesPlayed = 0;
    offlineWins = 0;
    onlineJoins = 0;
    onlineWins = 0;
    unlockedIds.clear();
    equippedId = null;
    _seenUnlockIds.clear();
    notifyListeners();
  }

  List<TitleDefinition> get catalog => kTitleCatalog;

  TitleDefinition? get equippedTitle =>
      equippedId == null ? null : titleById(equippedId!);

  int get unlockedCount => unlockedIds.length;

  int get newUnlockCount =>
      unlockedIds.where((id) => !_seenUnlockIds.contains(id)).length;

  bool isUnlocked(String id) => unlockedIds.contains(id);

  int statValue(TitleStatType stat) {
    switch (stat) {
      case TitleStatType.gamesPlayed:
        return gamesPlayed;
      case TitleStatType.offlineWins:
        return offlineWins;
      case TitleStatType.onlineJoins:
        return onlineJoins;
      case TitleStatType.onlineWins:
        return onlineWins;
    }
  }

  int progressFor(TitleDefinition def) {
    if (def.stat == null || def.statTarget == null) return 0;
    return statValue(def.stat!).clamp(0, def.statTarget!);
  }

  bool achievementMet(TitleDefinition def) {
    if (!def.hasAchievement) return false;
    return statValue(def.stat!) >= def.statTarget!;
  }

  bool canUnlockByAchievement(TitleDefinition def) =>
      !isUnlocked(def.id) && achievementMet(def);

  bool canPurchase(TitleDefinition def) =>
      !isUnlocked(def.id) && def.canPurchase;

  Future<void> load(String uid, {String? email}) async {
    final nextUid = uid.isEmpty ? 'guest' : uid;
    if (_loaded && _uid == nextUid) {
      await applyEmailGrants(email);
      return;
    }

    _uid = nextUid;
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'titles_$nextUid';

    gamesPlayed = prefs.getInt('$prefix.games') ?? 0;
    offlineWins = prefs.getInt('$prefix.offline_wins') ?? 0;
    onlineJoins = prefs.getInt('$prefix.online_joins') ?? 0;
    onlineWins = prefs.getInt('$prefix.online_wins') ?? 0;
    equippedId = prefs.getString('$prefix.equipped');

    final unlockedRaw = prefs.getString('$prefix.unlocked');
    if (unlockedRaw != null) {
      unlockedIds
        ..clear()
        ..addAll(List<String>.from(jsonDecode(unlockedRaw) as List));
    } else {
      unlockedIds.clear();
    }

    final seenRaw = prefs.getString('$prefix.seen');
    if (seenRaw != null) {
      _seenUnlockIds
        ..clear()
        ..addAll(List<String>.from(jsonDecode(seenRaw) as List));
    } else {
      _seenUnlockIds.clear();
    }

    _loaded = true;
    _checkAchievements(silent: true);
    await applyEmailGrants(email);
    notifyListeners();
  }

  /// Mở khóa toàn bộ danh hiệu cho email trong danh sách grant.
  Future<void> applyEmailGrants(String? email) async {
    if (!_loaded || email == null) return;
    final normalized = email.trim().toLowerCase();
    if (!kFullTitleGrantEmails.contains(normalized)) return;

    final allIds = catalog.map((t) => t.id).toSet();
    if (allIds.every(unlockedIds.contains)) return;

    unlockedIds.addAll(allIds);
    notifyListeners();
    await _save();
  }

  Future<void> unlockAllTitles() async {
    if (!_loaded) return;
    unlockedIds.addAll(catalog.map((t) => t.id));
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    if (!_canWrite) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'titles_$_uid';

    await prefs.setInt('$prefix.games', gamesPlayed);
    await prefs.setInt('$prefix.offline_wins', offlineWins);
    await prefs.setInt('$prefix.online_joins', onlineJoins);
    await prefs.setInt('$prefix.online_wins', onlineWins);

    if (equippedId != null) {
      await prefs.setString('$prefix.equipped', equippedId!);
    } else {
      await prefs.remove('$prefix.equipped');
    }

    await prefs.setString(
      '$prefix.unlocked',
      jsonEncode(unlockedIds.toList()),
    );
    await prefs.setString(
      '$prefix.seen',
      jsonEncode(_seenUnlockIds.toList()),
    );
  }

  void markAllUnlocksSeen() {
    _seenUnlockIds.addAll(unlockedIds);
    notifyListeners();
    _save();
  }

  void recordOfflinePlay() {
    if (!_canWrite) return;
    gamesPlayed++;
    notifyListeners();
    _save();
    _checkAchievements();
  }

  void recordOfflineWin() {
    if (!_canWrite) return;
    offlineWins++;
    notifyListeners();
    _save();
    _checkAchievements();
  }

  void recordOnlineJoin() {
    if (!_canWrite) return;
    onlineJoins++;
    notifyListeners();
    _save();
    _checkAchievements();
  }

  void recordOnlineWin() {
    if (!_canWrite) return;
    onlineWins++;
    notifyListeners();
    _save();
    _checkAchievements();
  }

  void _checkAchievements({bool silent = false}) {
    var changed = false;
    for (final def in catalog) {
      if (isUnlocked(def.id)) continue;
      if (achievementMet(def)) {
        unlockedIds.add(def.id);
        changed = true;
      }
    }
    if (changed && !silent) notifyListeners();
    if (changed) _save();
  }

  void equip(String id) {
    if (!_canWrite || !isUnlocked(id)) return;
    equippedId = id;
    notifyListeners();
    _save();
  }

  void unequip() {
    if (!_canWrite) return;
    equippedId = null;
    notifyListeners();
    _save();
  }

  Future<String?> purchase(String id) async {
    if (!_canWrite) return 'Đang tải danh hiệu...';
    final def = titleById(id);
    if (def == null) return 'Không tìm thấy danh hiệu.';
    if (isUnlocked(id)) return 'Bạn đã sở hữu danh hiệu này.';
    if (!def.canPurchase) return 'Danh hiệu này không bán bằng xu.';

    final err = await DailyQuestStore.instance.spendCoins(def.price!);
    if (err != null) return err;

    unlockedIds.add(id);
    notifyListeners();
    await _save();
    return null;
  }

  Future<String?> unlockFree(String id) async {
    if (!_canWrite) return 'Đang tải danh hiệu...';
    final def = titleById(id);
    if (def == null) return 'Không tìm thấy danh hiệu.';
    if (isUnlocked(id)) return 'Bạn đã sở hữu danh hiệu này.';
    if (!achievementMet(def)) return 'Chưa đủ điều kiện.';

    unlockedIds.add(id);
    notifyListeners();
    await _save();
    return null;
  }
}
