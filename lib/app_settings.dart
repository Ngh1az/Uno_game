import 'package:flutter/foundation.dart';

enum BotSpeed { slow, normal, fast }

/// Cài đặt toàn app — dùng chung cho sheet nhanh (login) và màn chi tiết (home).
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  // Âm thanh
  bool soundEnabled = true;
  double soundVolume = 0.8;
  bool musicEnabled = true;
  bool sfxEnabled = true;

  // Thông báo
  bool notificationsEnabled = true;
  bool roomInviteNotifications = true;
  bool turnNotifications = true;

  // Ngôn ngữ
  String languageCode = 'vi';

  // Trò chơi
  int defaultBotCount = 3;
  BotSpeed botSpeed = BotSpeed.normal;
  bool showPlayableHints = true;
  bool autoUnoCall = false;

  // Hiển thị
  bool cardAnimations = true;
  bool vibrationEnabled = true;

  String get languageLabel => languageCode == 'vi' ? 'Tiếng Việt' : 'English';

  String get botSpeedLabel => switch (botSpeed) {
    BotSpeed.slow => 'Chậm',
    BotSpeed.normal => 'Bình thường',
    BotSpeed.fast => 'Nhanh',
  };

  void setSoundEnabled(bool value) {
    if (soundEnabled == value) return;
    soundEnabled = value;
    notifyListeners();
  }

  void setSoundVolume(double value) {
    final v = value.clamp(0.0, 1.0);
    if (soundVolume == v) return;
    soundVolume = v;
    notifyListeners();
  }

  void setMusicEnabled(bool value) {
    if (musicEnabled == value) return;
    musicEnabled = value;
    notifyListeners();
  }

  void setSfxEnabled(bool value) {
    if (sfxEnabled == value) return;
    sfxEnabled = value;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    if (notificationsEnabled == value) return;
    notificationsEnabled = value;
    notifyListeners();
  }

  void setRoomInviteNotifications(bool value) {
    if (roomInviteNotifications == value) return;
    roomInviteNotifications = value;
    notifyListeners();
  }

  void setTurnNotifications(bool value) {
    if (turnNotifications == value) return;
    turnNotifications = value;
    notifyListeners();
  }

  void setLanguage(String code) {
    if (languageCode == code) return;
    languageCode = code;
    notifyListeners();
  }

  void setDefaultBotCount(int value) {
    final v = value.clamp(1, 5);
    if (defaultBotCount == v) return;
    defaultBotCount = v;
    notifyListeners();
  }

  void setBotSpeed(BotSpeed value) {
    if (botSpeed == value) return;
    botSpeed = value;
    notifyListeners();
  }

  void setShowPlayableHints(bool value) {
    if (showPlayableHints == value) return;
    showPlayableHints = value;
    notifyListeners();
  }

  void setAutoUnoCall(bool value) {
    if (autoUnoCall == value) return;
    autoUnoCall = value;
    notifyListeners();
  }

  void setCardAnimations(bool value) {
    if (cardAnimations == value) return;
    cardAnimations = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    if (vibrationEnabled == value) return;
    vibrationEnabled = value;
    notifyListeners();
  }
}
