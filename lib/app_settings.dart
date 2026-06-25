import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game_limits.dart';

enum BotSpeed { slow, normal, fast }

/// Cài đặt toàn app — dùng chung cho sheet nhanh (login) và màn chi tiết (home).
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _keyShowPlayableHints = 'showPlayableHints';
  static const _keyAutoUnoCall = 'autoUnoCall';
  static const _keyCardAnimations = 'cardAnimations';
  static const _keyDefaultBotCount = 'defaultBotCount';
  static const _keyBotSpeed = 'botSpeed';

  bool _loaded = false;

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

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    showPlayableHints = prefs.getBool(_keyShowPlayableHints) ?? showPlayableHints;
    autoUnoCall = prefs.getBool(_keyAutoUnoCall) ?? autoUnoCall;
    cardAnimations = prefs.getBool(_keyCardAnimations) ?? cardAnimations;
    defaultBotCount = prefs.getInt(_keyDefaultBotCount) ?? defaultBotCount;
    final speedName = prefs.getString(_keyBotSpeed);
    if (speedName != null) {
      botSpeed = BotSpeed.values.firstWhere(
        (s) => s.name == speedName,
        orElse: () => botSpeed,
      );
    }
    defaultBotCount = defaultBotCount.clamp(GameLimits.minBots, GameLimits.maxBots);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistGameSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowPlayableHints, showPlayableHints);
    await prefs.setBool(_keyAutoUnoCall, autoUnoCall);
    await prefs.setBool(_keyCardAnimations, cardAnimations);
    await prefs.setInt(_keyDefaultBotCount, defaultBotCount);
    await prefs.setString(_keyBotSpeed, botSpeed.name);
  }

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
    final v = value.clamp(GameLimits.minBots, GameLimits.maxBots);
    if (defaultBotCount == v) return;
    defaultBotCount = v;
    notifyListeners();
    _persistGameSettings();
  }

  void setBotSpeed(BotSpeed value) {
    if (botSpeed == value) return;
    botSpeed = value;
    notifyListeners();
    _persistGameSettings();
  }

  void setShowPlayableHints(bool value) {
    if (showPlayableHints == value) return;
    showPlayableHints = value;
    notifyListeners();
    _persistGameSettings();
  }

  void setAutoUnoCall(bool value) {
    if (autoUnoCall == value) return;
    autoUnoCall = value;
    notifyListeners();
    _persistGameSettings();
  }

  void setCardAnimations(bool value) {
    if (cardAnimations == value) return;
    cardAnimations = value;
    notifyListeners();
    _persistGameSettings();
  }

  void setVibrationEnabled(bool value) {
    if (vibrationEnabled == value) return;
    vibrationEnabled = value;
    notifyListeners();
  }
}
