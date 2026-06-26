import 'package:flutter/foundation.dart';

import '../app_settings.dart';
import '../game/game_limits.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import 'uno_bot.dart';

/// Điều khiển một ván UNO offline (người thật vs bot) và phát thông báo cho UI.
class GameController extends ChangeNotifier {
  static const String humanId = 'me';

  GameState? _state;
  GameState get state => _state!;
  bool get hasGame => _state != null;

  /// Độ trễ giữa các nước đi của bot — lấy từ [AppSettings.botSpeed].
  Duration get botDelay => _botDelayFromSettings(AppSettings.instance.botSpeed);

  /// True khi bot đang đi (khoá tương tác của người chơi).
  bool _botThinking = false;
  bool get botThinking => _botThinking;

  bool _disposed = false;

  static Duration _botDelayFromSettings(BotSpeed speed) => switch (speed) {
    BotSpeed.slow => const Duration(milliseconds: 1400),
    BotSpeed.normal => const Duration(milliseconds: 900),
    BotSpeed.fast => const Duration(milliseconds: 450),
  };

  /// Bắt đầu ván mới với [botCount] bot (tổng 2–10 người: bạn + bot).
  void startGame({
    int botCount = 3,
    String humanName = 'Bạn',
    bool runBots = true,
  }) {
    final bots = botCount.clamp(GameLimits.minBots, GameLimits.maxBots);
    final players = <UnoPlayer>[
      UnoPlayer(id: humanId, name: humanName),
      for (var i = 1; i <= bots; i++)
        UnoPlayer(id: 'bot$i', name: 'Bot $i', isBot: true),
    ];
    _state = GameState.newGame(players: players);
    _botThinking = false;
    notifyListeners();
    if (runBots) _runBotsIfNeeded();
  }

  /// Tiếp tục lượt bot sau intro mở ván.
  void resumeBots() => _runBotsIfNeeded();

  UnoPlayer get human => state.playerById(humanId);

  bool get isHumanTurn =>
      hasGame &&
      state.status == GameStatus.playing &&
      state.currentPlayer.id == humanId;

  bool get isFinished => hasGame && state.status == GameStatus.finished;

  /// Người chơi có thể "qua lượt" (đã rút bài trong lượt này).
  bool get canPass => isHumanTurn && state.drawnThisTurn;

  List<UnoCard> get humanPlayable =>
      isHumanTurn ? state.playableCards(human) : const [];

  bool canPlay(UnoCard card) => isHumanTurn && state.canPlay(card);

  /// Người chơi qua lượt sau khi đã rút.
  void passHuman() {
    if (!canPass || _botThinking) return;
    state.endTurn(humanId);
    notifyListeners();
    _runBotsIfNeeded();
  }

  void callUno() {
    if (!isHumanTurn || _botThinking) return;
    state.callUno(humanId);
    notifyListeners();
  }

  void catchUno(String targetId) {
    if (!hasGame || state.status != GameStatus.playing || _botThinking) return;
    state.catchUno(humanId, targetId);
    notifyListeners();
    _runBotsIfNeeded();
  }

  void acceptDrawStack() {
    if (!isHumanTurn || _botThinking) return;
    state.acceptDrawStack(humanId);
    notifyListeners();
    _runBotsIfNeeded();
  }

  /// Người chơi đánh một lá. Với lá Wild cần truyền [chosenColor].
  void playHuman(UnoCard card, {CardColor? chosenColor, int? handIndex}) {
    if (!isHumanTurn || _botThinking) return;
    state.playCard(
      humanId,
      card,
      chosenColor: chosenColor,
      handIndex: handIndex,
      declaredUno: state.hasDeclaredUno(humanId),
      autoUno: AppSettings.instance.autoUnoCall,
    );
    notifyListeners();
    _runBotsIfNeeded();
  }

  /// Người chơi rút 1 lá.
  void drawHuman() {
    if (!isHumanTurn || _botThinking || state.drawnThisTurn) return;
    state.drawCard(humanId);
    notifyListeners();
    _runBotsIfNeeded();
  }

  /// Cho các bot lần lượt đi cho tới khi tới lượt người thật hoặc ván kết thúc.
  Future<void> _runBotsIfNeeded() async {
    if (!hasGame || _botThinking) return;
    if (state.status != GameStatus.playing) return;
    if (!state.currentPlayer.isBot) return;

    _botThinking = true;
    notifyListeners();

    while (state.status == GameStatus.playing &&
        state.currentPlayer.isBot &&
        !_disposed) {
      await Future.delayed(botDelay);
      if (_disposed) return;
      UnoBot.takeTurn(state);
      notifyListeners();
    }

    _botThinking = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
