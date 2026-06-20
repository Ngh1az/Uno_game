import 'package:firebase_auth/firebase_auth.dart';

import '../daily_quests/daily_quest_store.dart';
import '../titles/title_store.dart';

/// Gắn dữ liệu local (nhiệm vụ, danh hiệu, xu…) theo uid Firebase.
abstract final class UserSession {
  static String? _activeUid;

  static String? get activeUid => _activeUid;

  static bool isActiveUid(String storeUid) =>
      _activeUid != null &&
      storeUid.isNotEmpty &&
      storeUid == _activeUid;

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
    final email = u.email?.trim().toLowerCase();

    await DailyQuestStore.instance.load(uid, isGuest: isGuest);
    await TitleStore.instance.load(uid, email: email);
  }

  /// Xóa cache RAM khi đăng xuất — tránh ghi nhầm sang user khác.
  static Future<void> deactivate() async {
    _activeUid = null;
    DailyQuestStore.instance.unbind();
    TitleStore.instance.unbind();
  }
}
