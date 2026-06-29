/// Nhãn hiển thị người chơi — phân biệt khách trùng tên mặc định.
abstract final class PlayerDisplayName {
  static const _defaultNames = {'khách', 'người chơi'};

  static bool isDefaultGuestName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return true;
    return _defaultNames.contains(trimmed.toLowerCase());
  }

  /// 4 ký tự cuối uid (in hoa) — đủ phân biệt trong phòng nhỏ.
  static String uidSuffix(String uid, {int length = 4}) {
    if (uid.isEmpty) return '????';
    if (uid.length <= length) return uid.toUpperCase();
    return uid.substring(uid.length - length).toUpperCase();
  }

  /// Tên trong phòng / lobby; khách chưa đặt tên → `Khách #AB12`.
  static String roomLabel(String name, String playerId) {
    if (!isDefaultGuestName(name)) return name.trim();
    return 'Khách #${uidSuffix(playerId)}';
  }
}
