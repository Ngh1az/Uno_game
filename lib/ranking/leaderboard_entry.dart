/// Một dòng trên bảng xếp hạng.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.value,
    this.photoUrl,
    this.equippedTitleId,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? equippedTitleId;
  final int value;
}

enum LeaderboardMetric {
  onlineWins('onlineWins', 'Thắng online', 'ván'),
  coins('coins', 'Xu UNO', 'xu'),
  offlineWins('offlineWins', 'Thắng offline', 'ván');

  const LeaderboardMetric(this.field, this.label, this.unit);

  final String field;
  final String label;
  final String unit;
}
