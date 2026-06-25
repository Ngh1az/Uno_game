/// Mật độ chip đối thủ theo số người trên hàng.
enum OpponentChipDensity {
  /// ≤3 đối thủ — đủ chỗ icon + tên danh hiệu + tên.
  roomy,

  /// 4–6 — icon luôn; chữ danh hiệu khi tới lượt.
  compact,

  /// 7+ cuộn ngang — gọn nhất.
  tight,
}

extension OpponentChipDensityX on OpponentChipDensity {
  static OpponentChipDensity forOpponentCount(int count) {
    if (count <= 3) return OpponentChipDensity.roomy;
    if (count <= 6) return OpponentChipDensity.compact;
    return OpponentChipDensity.tight;
  }

  /// Bot offline — chip thấp gọn, không danh hiệu.
  static OpponentChipDensity forBotCount(int count) {
    if (count <= 3) return OpponentChipDensity.roomy;
    if (count <= 6) return OpponentChipDensity.compact;
    return OpponentChipDensity.tight;
  }

  double get chipWidth => switch (this) {
        OpponentChipDensity.roomy => 80,
        OpponentChipDensity.compact => 72,
        OpponentChipDensity.tight => 68,
      };

  double get botChipWidth => switch (this) {
        OpponentChipDensity.roomy => 68,
        OpponentChipDensity.compact => 58,
        OpponentChipDensity.tight => 56,
      };

  double get rowHeight => switch (this) {
        OpponentChipDensity.roomy => 92,
        OpponentChipDensity.compact => 88,
        OpponentChipDensity.tight => 88,
      };

  double get botRowHeight => switch (this) {
        OpponentChipDensity.roomy => 72,
        OpponentChipDensity.compact => 68,
        OpponentChipDensity.tight => 68,
      };

  double get avatarRadius => switch (this) {
        OpponentChipDensity.roomy => 20,
        OpponentChipDensity.compact => 17,
        OpponentChipDensity.tight => 15,
      };

  double get botAvatarRadius => switch (this) {
        OpponentChipDensity.roomy => 18,
        OpponentChipDensity.compact => 15,
        OpponentChipDensity.tight => 14,
      };

  double get cardBackWidth => switch (this) {
        OpponentChipDensity.roomy => 36,
        OpponentChipDensity.compact => 32,
        OpponentChipDensity.tight => 28,
      };

  double get nameFontSize => switch (this) {
        OpponentChipDensity.roomy => 10,
        OpponentChipDensity.compact => 9,
        OpponentChipDensity.tight => 8,
      };

  int get nameMaxChars => switch (this) {
        OpponentChipDensity.roomy => 10,
        OpponentChipDensity.compact => 8,
        OpponentChipDensity.tight => 6,
      };

  bool showTitleText(bool isTurn) => switch (this) {
        OpponentChipDensity.roomy => true,
        OpponentChipDensity.compact => isTurn,
        OpponentChipDensity.tight => isTurn,
      };
}
