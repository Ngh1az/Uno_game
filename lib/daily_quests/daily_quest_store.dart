import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user/user_session.dart';
import 'daily_quest.dart';

/// Lưu nhiệm vụ ngày + tuần trên máy — **theo uid**, không chia sẻ giữa tài khoản.
class DailyQuestStore extends ChangeNotifier {
  DailyQuestStore._();

  static final DailyQuestStore instance = DailyQuestStore._();

  static const _keyDailyDate = 'daily_quest_date';
  static const _keyDailyData = 'daily_quest_data';
  static const _keyWeeklyWeek = 'weekly_quest_week';
  static const _keyWeeklyData = 'weekly_quest_data';
  static const _keyWeeklyLoginDays = 'weekly_login_days';
  static const _keyCoins = 'daily_quest_coins';
  static const _keyLegacyMigratedUid = 'daily_quest_legacy_migrated_uid';

  bool _loaded = false;
  String _uid = '';
  String _today = '';
  String _weekKey = '';
  List<String> _weeklyLoginDays = [];
  List<DailyQuest> dailyQuests = [];
  List<DailyQuest> weeklyQuests = [];
  int coins = 0;

  String _prefix(String uid) => 'dq_${uid.isEmpty ? 'guest' : uid}';

  String _k(String uid, String suffix) => '${_prefix(uid)}_$suffix';

  bool get _canWrite => _loaded && UserSession.isActiveUid(_uid);

  /// Gỡ cache RAM khi đổi / đăng xuất tài khoản.
  void unbind() {
    _loaded = false;
    _uid = '';
    _today = '';
    _weekKey = '';
    _weeklyLoginDays = [];
    dailyQuests = [];
    weeklyQuests = [];
    coins = 0;
    notifyListeners();
  }

  List<DailyQuest> get quests => dailyQuests;

  DailyQuest _quest({
    required String id,
    required String title,
    required IconData icon,
    required int target,
    required int reward,
    Object? saved,
  }) {
    final map = saved is Map ? Map<String, dynamic>.from(saved) : null;
    return DailyQuest(
      id: id,
      title: title,
      icon: icon,
      target: target,
      reward: reward,
      progress: map?['progress'] as int? ?? 0,
      claimed: map?['claimed'] as bool? ?? false,
    );
  }

  List<DailyQuest> _buildDaily(Map<String, dynamic> saved) => [
        _quest(
          id: 'login',
          title: 'Đăng nhập hôm nay',
          icon: Icons.wb_sunny_rounded,
          target: 1,
          reward: 30,
          saved: saved['login'],
        ),
        _quest(
          id: 'play_offline',
          title: 'Chơi 1 ván với máy',
          icon: Icons.smart_toy_rounded,
          target: 1,
          reward: 50,
          saved: saved['play_offline'],
        ),
        _quest(
          id: 'play_offline_3',
          title: 'Chơi 3 ván với máy',
          icon: Icons.casino_rounded,
          target: 3,
          reward: 120,
          saved: saved['play_offline_3'],
        ),
        _quest(
          id: 'win_offline',
          title: 'Thắng 1 ván với máy',
          icon: Icons.emoji_events_rounded,
          target: 1,
          reward: 80,
          saved: saved['win_offline'],
        ),
        _quest(
          id: 'online_join',
          title: 'Vào phòng online',
          icon: Icons.public_rounded,
          target: 1,
          reward: 60,
          saved: saved['online_join'],
        ),
      ];

  List<DailyQuest> _buildWeekly(Map<String, dynamic> saved) => [
        _quest(
          id: 'login_days',
          title: 'Đăng nhập 5 ngày',
          icon: Icons.calendar_today_rounded,
          target: 5,
          reward: 250,
          saved: saved['login_days'],
        ),
        _quest(
          id: 'play_games',
          title: 'Chơi 10 ván',
          icon: Icons.style_rounded,
          target: 10,
          reward: 350,
          saved: saved['play_games'],
        ),
        _quest(
          id: 'win_games',
          title: 'Thắng 5 ván',
          icon: Icons.military_tech_rounded,
          target: 5,
          reward: 450,
          saved: saved['win_games'],
        ),
        _quest(
          id: 'online_games',
          title: 'Chơi online 5 lần',
          icon: Icons.groups_rounded,
          target: 5,
          reward: 300,
          saved: saved['online_games'],
        ),
      ];

  Future<void> load(String uid, {bool isGuest = false}) async {
    final nextUid = uid.isEmpty ? 'guest' : uid;
    if (_loaded && _uid == nextUid) return;

    _uid = nextUid;
    _loaded = false;

    final prefs = await SharedPreferences.getInstance();
    if (!isGuest) {
      await _migrateLegacyForUid(prefs, nextUid);
    }

    final now = DateTime.now();
    _today = _formatDate(now);
    _weekKey = _formatWeekKey(now);
    coins = prefs.getInt(_k(nextUid, 'coins')) ?? 0;

    final savedDailyDate = prefs.getString(_k(nextUid, 'daily_date'));
    Map<String, dynamic> savedDaily = {};
    if (savedDailyDate == _today) {
      final raw = prefs.getString(_k(nextUid, 'daily_data'));
      if (raw != null) {
        savedDaily = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } else {
      await prefs.setString(_k(nextUid, 'daily_date'), _today);
      await prefs.remove(_k(nextUid, 'daily_data'));
    }

    final savedWeeklyWeek = prefs.getString(_k(nextUid, 'weekly_week'));
    Map<String, dynamic> savedWeekly = {};
    if (savedWeeklyWeek == _weekKey) {
      final raw = prefs.getString(_k(nextUid, 'weekly_data'));
      if (raw != null) {
        savedWeekly = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
      final loginRaw = prefs.getString(_k(nextUid, 'weekly_login_days'));
      if (loginRaw != null) {
        _weeklyLoginDays = List<String>.from(jsonDecode(loginRaw) as List);
      }
    } else {
      await prefs.setString(_k(nextUid, 'weekly_week'), _weekKey);
      await prefs.remove(_k(nextUid, 'weekly_data'));
      await prefs.remove(_k(nextUid, 'weekly_login_days'));
      _weeklyLoginDays = [];
    }

    dailyQuests = _buildDaily(savedDaily);
    weeklyQuests = _buildWeekly(savedWeekly);

    _loaded = true;
    markLogin();
    notifyListeners();
  }

  /// Chuyển dữ liệu cũ (chung máy) sang uid đang đăng nhập — một lần.
  Future<void> _migrateLegacyForUid(
    SharedPreferences prefs,
    String uid,
  ) async {
    if (prefs.getString(_keyLegacyMigratedUid) == uid) return;
    if (prefs.containsKey(_k(uid, 'coins')) ||
        prefs.containsKey(_k(uid, 'daily_data'))) {
      await prefs.setString(_keyLegacyMigratedUid, uid);
      return;
    }

    final hasLegacy = prefs.containsKey(_keyCoins) ||
        prefs.containsKey(_keyDailyData) ||
        prefs.containsKey(_keyWeeklyData);
    if (!hasLegacy) return;

    Future<void> copy(String legacyKey, String newKey) async {
      final value = prefs.get(legacyKey);
      if (value == null) return;
      if (value is int) {
        await prefs.setInt(newKey, value);
      } else if (value is String) {
        await prefs.setString(newKey, value);
      } else if (value is bool) {
        await prefs.setBool(newKey, value);
      }
    }

    await copy(_keyCoins, _k(uid, 'coins'));
    await copy(_keyDailyDate, _k(uid, 'daily_date'));
    await copy(_keyDailyData, _k(uid, 'daily_data'));
    await copy(_keyWeeklyWeek, _k(uid, 'weekly_week'));
    await copy(_keyWeeklyData, _k(uid, 'weekly_data'));
    await copy(_keyWeeklyLoginDays, _k(uid, 'weekly_login_days'));
    await prefs.setString(_keyLegacyMigratedUid, uid);

    await prefs.remove(_keyCoins);
    await prefs.remove(_keyDailyDate);
    await prefs.remove(_keyDailyData);
    await prefs.remove(_keyWeeklyWeek);
    await prefs.remove(_keyWeeklyData);
    await prefs.remove(_keyWeeklyLoginDays);
  }

  Future<void> _saveDaily() async {
    if (!_canWrite) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(_uid, 'daily_date'), _today);
    final data = {for (final q in dailyQuests) q.id: q.toJson()};
    await prefs.setString(_k(_uid, 'daily_data'), jsonEncode(data));
    await prefs.setInt(_k(_uid, 'coins'), coins);
  }

  Future<void> _saveWeekly() async {
    if (!_canWrite) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(_uid, 'weekly_week'), _weekKey);
    final data = {for (final q in weeklyQuests) q.id: q.toJson()};
    await prefs.setString(_k(_uid, 'weekly_data'), jsonEncode(data));
    await prefs.setString(
      _k(_uid, 'weekly_login_days'),
      jsonEncode(_weeklyLoginDays),
    );
    await prefs.setInt(_k(_uid, 'coins'), coins);
  }

  void _bumpDaily(String id, {int amount = 1}) {
    if (!_canWrite) return;
    final quest = dailyQuests.firstWhere((q) => q.id == id);
    if (quest.isComplete) return;
    quest.progress = (quest.progress + amount).clamp(0, quest.target);
    notifyListeners();
    _saveDaily();
  }

  void _bumpWeekly(String id, {int amount = 1}) {
    if (!_canWrite) return;
    final quest = weeklyQuests.firstWhere((q) => q.id == id);
    if (quest.isComplete) return;
    quest.progress = (quest.progress + amount).clamp(0, quest.target);
    notifyListeners();
    _saveWeekly();
  }

  void markLogin() {
    if (!_canWrite) return;
    _bumpDaily('login');
    if (!_weeklyLoginDays.contains(_today)) {
      _weeklyLoginDays = [..._weeklyLoginDays, _today];
      final quest = weeklyQuests.firstWhere((q) => q.id == 'login_days');
      quest.progress = _weeklyLoginDays.length.clamp(0, quest.target);
      notifyListeners();
      _saveWeekly();
    }
  }

  void markOfflinePlay() {
    _bumpDaily('play_offline');
    _bumpDaily('play_offline_3');
    _bumpWeekly('play_games');
  }

  void markOfflineWin() {
    _bumpDaily('win_offline');
    _bumpWeekly('win_games');
  }

  void markOnlineJoin() {
    _bumpDaily('online_join');
    _bumpWeekly('online_games');
  }

  DailyQuest? _findQuest(String id) {
    for (final q in dailyQuests) {
      if (q.id == id) return q;
    }
    for (final q in weeklyQuests) {
      if (q.id == id) return q;
    }
    return null;
  }

  bool _isWeekly(String id) =>
      weeklyQuests.any((quest) => quest.id == id);

  Future<String?> claim(String id) async {
    if (!_canWrite) return 'Đang tải nhiệm vụ...';
    final quest = _findQuest(id);
    if (quest == null || !quest.canClaim) {
      return 'Chưa hoàn thành hoặc đã nhận thưởng.';
    }
    quest.claimed = true;
    coins += quest.reward;
    notifyListeners();
    if (_isWeekly(id)) {
      await _saveWeekly();
    } else {
      await _saveDaily();
    }
    return null;
  }

  int get claimableCount =>
      dailyQuests.where((q) => q.canClaim).length +
      weeklyQuests.where((q) => q.canClaim).length;

  /// Trừ xu (mua danh hiệu, v.v.). Trả về lỗi hoặc null nếu thành công.
  Future<String?> spendCoins(int amount) async {
    if (!_canWrite) return 'Đang tải...';
    if (amount <= 0) return null;
    if (coins < amount) return 'Không đủ xu UNO.';
    coins -= amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_k(_uid, 'coins'), coins);
    return null;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Tuần bắt đầu từ thứ Hai (local).
  String _formatWeekKey(DateTime dt) {
    final monday = dt.subtract(Duration(days: dt.weekday - DateTime.monday));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}
