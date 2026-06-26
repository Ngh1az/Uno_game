import '../app_settings.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';

/// Tự động hoàn thành lượt khi hết giờ (logic tương tự bot, dùng cho timeout).
class AutoTurnPlayer {
  AutoTurnPlayer._();

  static void takeTurn(
    GameState state, {
    bool? autoUno,
    String? playerId,
  }) {
    final pid = playerId ?? state.currentPlayer.id;
    final uno = autoUno ?? AppSettings.instance.autoUnoCall;
    try {
      _takeTurnImpl(state, pid, autoUno: uno);
    } catch (_) {
      _forcePass(state, pid);
    }
  }

  static void _takeTurnImpl(
    GameState state,
    String playerId, {
    required bool autoUno,
  }) {
    final catchable = state.catchableUnoPlayerId;
    if (catchable != null && catchable != playerId) {
      state.catchUno(playerId, catchable);
    }

    if (state.mustRespondToDrawStack) {
      final stackable = state
          .playableCards(state.currentPlayer)
          .where(
            (c) =>
                c.type == CardType.drawTwo ||
                c.type == CardType.wildDrawFour,
          )
          .toList();
      if (stackable.isNotEmpty) {
        _play(state, playerId, stackable.first, autoUno: autoUno);
      } else {
        state.acceptDrawStack(playerId);
      }
      return;
    }

    final playable = state.playableCards(state.currentPlayer);
    if (playable.isNotEmpty) {
      _play(state, playerId, _chooseCard(playable), autoUno: autoUno);
      return;
    }

    final drawn = state.drawCard(playerId);
    if (state.status == GameStatus.playing &&
        state.currentPlayer.id == playerId &&
        state.canPlay(drawn)) {
      _play(state, playerId, drawn, autoUno: autoUno);
    }
  }

  static void _forcePass(GameState state, String playerId) {
    state.log.add('${state.currentPlayer.name} treo máy — bỏ lượt.');
    if (state.mustRespondToDrawStack) {
      state.acceptDrawStack(playerId);
      return;
    }
    if (state.drawnThisTurn) {
      state.endTurn(playerId);
      return;
    }
    state.drawCard(playerId);
  }

  static void _play(
    GameState state,
    String playerId,
    UnoCard card, {
    required bool autoUno,
  }) {
    final player = state.currentPlayer;
    final declaredUno = state.hasDeclaredUno(playerId) ||
        (autoUno && player.hand.length == 2);
    if (!declaredUno && player.hand.length == 2) {
      state.callUno(playerId);
    }
    final color = card.isWild ? _chooseColor(state) : null;
    state.playCard(
      playerId,
      card,
      chosenColor: color,
      declaredUno: state.hasDeclaredUno(playerId) || declaredUno,
      autoUno: autoUno,
    );
  }

  static UnoCard _chooseCard(List<UnoCard> playable) {
    final nonWild = playable.where((c) => !c.isWild).toList();
    final pool = nonWild.isNotEmpty ? nonWild : playable;
    return pool.first;
  }

  static CardColor _chooseColor(GameState state) {
    final counts = <CardColor, int>{
      CardColor.red: 0,
      CardColor.yellow: 0,
      CardColor.green: 0,
      CardColor.blue: 0,
    };
    for (final c in state.currentPlayer.hand) {
      if (c.color != CardColor.wild) {
        counts[c.color] = counts[c.color]! + 1;
      }
    }
    var best = CardColor.red;
    var max = -1;
    counts.forEach((color, n) {
      if (n > max) {
        max = n;
        best = color;
      }
    });
    return best;
  }
}
