import '../models/game_state.dart';
import '../models/uno_card.dart';

/// AI đơn giản cho người chơi bot.
class UnoBot {
  /// Thực hiện trọn vẹn 1 lượt cho người chơi bot đang tới lượt.
  static void takeTurn(GameState state) {
    final bot = state.currentPlayer;
    if (!bot.isBot) return;

    final catchable = state.catchableUnoPlayerId;
    if (catchable != null && catchable != bot.id) {
      state.catchUno(bot.id, catchable);
    }

    if (state.mustRespondToDrawStack) {
      final stackable = state
          .playableCards(bot)
          .where(
            (c) =>
                c.type == CardType.drawTwo ||
                c.type == CardType.wildDrawFour,
          )
          .toList();
      if (stackable.isNotEmpty) {
        _play(state, stackable.first);
      } else {
        state.acceptDrawStack(bot.id);
      }
      return;
    }

    final playable = state.playableCards(bot);
    if (playable.isNotEmpty) {
      _play(state, _chooseCard(playable));
      return;
    }

    final drawn = state.drawCard(bot.id);
    if (state.status == GameStatus.playing &&
        state.currentPlayer.id == bot.id &&
        state.canPlay(drawn)) {
      _play(state, drawn);
    }
  }

  static void _play(GameState state, UnoCard card) {
    final bot = state.currentPlayer;
    if (bot.hand.length == 2) {
      state.callUno(bot.id);
    }
    final color = card.isWild ? _chooseColor(state) : null;
    state.playCard(
      bot.id,
      card,
      chosenColor: color,
      declaredUno: state.hasDeclaredUno(bot.id),
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
