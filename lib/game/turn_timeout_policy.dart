/// Chính sách timeout lượt chơi online.
class TurnTimeoutPolicy {
  TurnTimeoutPolicy._();

  static const turnDuration = Duration(seconds: 60);
  static const maxStrikes = 3;
  static const watcherInterval = Duration(seconds: 5);
  static const countdownTick = Duration(seconds: 1);
}
