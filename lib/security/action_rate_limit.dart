import 'package:shared_preferences/shared_preferences.dart';

/// Giới hạn tần suất thao tác nhạy cảm (theo uid hoặc theo máy).
abstract final class ActionRateLimit {
  static final _memory = <String, List<int>>{};

  static const _guestKey = 'rl_guest_sign_in_v1';

  /// Trả về thông báo lỗi nếu vượt giới hạn; null nếu được phép.
  static String? tryAcquire(
    String key, {
    required int limit,
    required Duration window,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final times = _memory.putIfAbsent(key, () => [])
      ..removeWhere((t) => now - t > windowMs);
    if (times.length >= limit) {
      final waitSec = _waitSeconds(now, times.first, windowMs);
      return 'Quá nhiều lần thử. Đợi ${waitSec}s.';
    }
    times.add(now);
    return null;
  }

  static String? forUid(
    String action,
    String uid, {
    required int limit,
    required Duration window,
  }) {
    if (uid.isEmpty) return 'Cần đăng nhập.';
    return tryAcquire('$action:$uid', limit: limit, window: window);
  }

  /// Khách: giới hạn theo máy (chống spam tạo/xóa acc).
  static Future<String?> tryGuestSignIn() async {
    const limit = 5;
    const window = Duration(hours: 1);
    const burstLimit = 2;
    const burstWindow = Duration(minutes: 2);

    final burst = tryAcquire('guest_burst', limit: burstLimit, window: burstWindow);
    if (burst != null) return burst;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final raw = prefs.getStringList(_guestKey) ?? [];
    final times = raw
        .map(int.tryParse)
        .whereType<int>()
        .where((t) => now - t <= windowMs)
        .toList();
    if (times.length >= limit) {
      final waitSec = _waitSeconds(now, times.first, windowMs);
      return 'Tạo tài khoản khách quá nhanh. Đợi ${waitSec}s.';
    }
    times.add(now);
    await prefs.setStringList(
      _guestKey,
      times.map((t) => t.toString()).toList(),
    );
    return null;
  }

  static int _waitSeconds(int nowMs, int oldestMs, int windowMs) {
    final remain = windowMs - (nowMs - oldestMs);
    return (remain / 1000).ceil().clamp(1, 9999);
  }
}

/// Giới hạn giá trị đồng bộ cloud (chống chỉnh client quá đà).
abstract final class ProgressBounds {
  static const maxCoins = 200000;
  static const maxStat = 100000;
  static const maxUnlockedTitles = 64;

  static int clampCoins(int value) => value.clamp(0, maxCoins);

  static int clampStat(int value) => value.clamp(0, maxStat);

  static Set<String> clampUnlocked(Set<String> ids) {
    if (ids.length <= maxUnlockedTitles) return ids;
    return ids.take(maxUnlockedTitles).toSet();
  }

  /// Chỉ cho phép tăng stat tối đa [maxDelta] mỗi lần push (chống nhảy số).
  static int mergeStat(int local, int remote, {int maxDelta = 15}) {
    final merged = local > remote ? local : remote;
    final baseline = remote > local ? remote : local;
    final cap = baseline + maxDelta;
    return clampStat(merged > cap ? cap : merged);
  }
}
