import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Gộp xu / nhiệm vụ / danh hiệu local khi đổi uid (khách → Google trên cùng máy).
abstract final class LocalProgressMigrator {
  static Future<bool> migrate(String fromUid, String toUid) async {
    if (fromUid.isEmpty || toUid.isEmpty || fromUid == toUid) return false;

    final prefs = await SharedPreferences.getInstance();
    final doneKey = 'progress_migrated_${fromUid}_to_$toUid';
    if (prefs.getBool(doneKey) == true) return false;

    await _mergeDailyQuests(prefs, fromUid, toUid);
    await _mergeTitles(prefs, fromUid, toUid);

    await prefs.setBool(doneKey, true);
    return true;
  }

  static Future<void> _mergeDailyQuests(
    SharedPreferences prefs,
    String fromUid,
    String toUid,
  ) async {
    final from = 'dq_$fromUid';
    final to = 'dq_$toUid';

    final fromCoins = prefs.getInt('${from}_coins') ?? 0;
    if (fromCoins > 0) {
      final toCoins = prefs.getInt('${to}_coins') ?? 0;
      await prefs.setInt('${to}_coins', fromCoins + toCoins);
    }

    for (final suffix in [
      'daily_date',
      'daily_data',
      'weekly_week',
      'weekly_data',
      'weekly_login_days',
    ]) {
      final fromKey = '${from}_$suffix';
      final toKey = '${to}_$suffix';
      if (!prefs.containsKey(toKey) && prefs.containsKey(fromKey)) {
        await _copyValue(prefs, fromKey, toKey);
      }
    }
  }

  static Future<void> _mergeTitles(
    SharedPreferences prefs,
    String fromUid,
    String toUid,
  ) async {
    final from = 'titles_$fromUid';
    final to = 'titles_$toUid';

    for (final stat in [
      'games',
      'offline_wins',
      'online_joins',
      'online_wins',
    ]) {
      final fromVal = prefs.getInt('$from.$stat') ?? 0;
      final toVal = prefs.getInt('$to.$stat') ?? 0;
      final merged = fromVal > toVal ? fromVal : toVal;
      if (merged > 0) {
        await prefs.setInt('$to.$stat', merged);
      }
    }

    if (!prefs.containsKey('$to.equipped')) {
      final equipped = prefs.getString('$from.equipped');
      if (equipped != null) {
        await prefs.setString('$to.equipped', equipped);
      }
    }

    final unlocked = _readStringSet(prefs, '$from.unlocked')
      ..addAll(_readStringSet(prefs, '$to.unlocked'));
    if (unlocked.isNotEmpty) {
      await prefs.setString('$to.unlocked', jsonEncode(unlocked.toList()));
    }

    final seen = _readStringSet(prefs, '$from.seen')
      ..addAll(_readStringSet(prefs, '$to.seen'));
    if (seen.isNotEmpty) {
      await prefs.setString('$to.seen', jsonEncode(seen.toList()));
    }
  }

  static Set<String> _readStringSet(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    return Set<String>.from(jsonDecode(raw) as List);
  }

  static Future<void> _copyValue(
    SharedPreferences prefs,
    String fromKey,
    String toKey,
  ) async {
    final value = prefs.get(fromKey);
    if (value == null) return;
    if (value is int) {
      await prefs.setInt(toKey, value);
    } else if (value is String) {
      await prefs.setString(toKey, value);
    } else if (value is bool) {
      await prefs.setBool(toKey, value);
    }
  }
}
