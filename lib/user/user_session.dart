import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../daily_quests/daily_quest_store.dart';
import '../online/guest_session_store.dart';
import '../titles/title_store.dart';
import 'cloud_progress_service.dart';
import 'local_progress_migrator.dart';

/// Gắn dữ liệu local (nhiệm vụ, danh hiệu, xu…) theo uid Firebase.
abstract final class UserSession {
  static const _keyLastGuestProgressUid = 'last_guest_progress_uid';

  static String? _activeUid;
  static bool _isGuestAccount = false;

  /// `true` nếu lần đồng bộ cloud gần nhất thất bại (mạng / quyền) — UI có thể
  /// cảnh báo người chơi rằng tiến độ có thể chưa được lưu lên đám mây.
  static bool lastCloudSyncFailed = false;

  static String? get activeUid => _activeUid;

  static bool get syncsToCloud => _activeUid != null && !_isGuestAccount;

  static bool isActiveUid(String storeUid) =>
      _activeUid != null &&
      storeUid.isNotEmpty &&
      storeUid == _activeUid;

  /// Nhớ uid khách trước khi nâng cấp lên Google (gộp xu / danh hiệu).
  static Future<void> rememberGuestProgressUid(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastGuestProgressUid, uid);
  }

  /// Nạp dữ liệu của user đang đăng nhập.
  static Future<void> activate(User? user) async {
    final u = user;
    if (u == null) {
      await deactivate();
      return;
    }

    final uid = u.uid;
    if (uid.isEmpty) {
      await deactivate();
      return;
    }

    _activeUid = uid;
    final isGuest = u.isAnonymous;
    _isGuestAccount = isGuest;
    final email = u.email?.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();

    if (isGuest) {
      await prefs.setString(_keyLastGuestProgressUid, uid);
    } else {
      var guestUid = prefs.getString(_keyLastGuestProgressUid);
      guestUid ??= await GuestSessionStore.readUid();
      if (guestUid != null && guestUid != uid) {
        await LocalProgressMigrator.migrate(guestUid, uid);
      }
    }

    await DailyQuestStore.instance.load(uid, isGuest: isGuest);
    await TitleStore.instance.load(uid, email: email);

    if (!isGuest) {
      final ok = await CloudProgressService.instance.sync(
        uid,
        displayName: u.displayName,
        photoUrl: u.photoURL,
      );
      lastCloudSyncFailed = !ok;
    } else {
      lastCloudSyncFailed = false;
    }
  }

  /// Xóa cache RAM khi đăng xuất — tránh ghi nhầm sang user khác.
  static Future<void> deactivate() async {
    _activeUid = null;
    _isGuestAccount = false;
    DailyQuestStore.instance.unbind();
    TitleStore.instance.unbind();
  }
}
