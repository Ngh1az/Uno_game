import 'package:shared_preferences/shared_preferences.dart';

/// Lưu thông tin khách trên máy (backup khi Firebase khôi phục phiên).
class GuestSessionStore {
  GuestSessionStore._();

  static const _keyUid = 'guest_uid';
  static const _keyDisplayName = 'guest_display_name';

  static Future<void> save({
    required String uid,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_keyDisplayName, name);
    }
  }

  static Future<String?> readDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDisplayName);
  }

  static Future<String?> readUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUid);
    await prefs.remove(_keyDisplayName);
  }
}
