/// Giới hạn người chơi theo luật UNO chuẩn (Mattel: 2–10 người).
abstract final class GameLimits {
  static const int minPlayers = 2;
  static const int maxPlayers = 10;

  /// Offline: 1 người + bot.
  static const int minBots = minPlayers - 1;
  static const int maxBots = maxPlayers - 1;
}
