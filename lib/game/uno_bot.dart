import '../models/game_state.dart';
import '../models/uno_card.dart';

/// AI đơn giản cho người chơi bot.
class UnoBot {
  /// Thực hiện trọn vẹn 1 lượt cho người chơi bot đang tới lượt.
  ///
  /// Chiến lược:
  /// 1. Nếu có lá đánh được -> ưu tiên đánh lá thường/đặc biệt trước, để dành Wild.
  /// 2. Nếu không có -> rút 1 lá; rút được lá đánh được thì đánh, không thì qua lượt.
  static void takeTurn(GameState state) {
    final bot = state.currentPlayer;
    if (!bot.isBot) return;

    final playable = state.playableCards(bot);
    if (playable.isNotEmpty) {
      _play(state, _chooseCard(playable));
      return;
    }

    // Không có lá nào -> rút.
    final drawn = state.drawCard(bot.id);
    // Nếu sau khi rút vẫn tới lượt bot (lá rút đánh được) thì đánh luôn.
    if (state.status == GameStatus.playing &&
        state.currentPlayer.id == bot.id &&
        state.canPlay(drawn)) {
      _play(state, drawn);
    }
    // Nếu lá rút không đánh được, engine đã tự chuyển lượt rồi.
  }

  static void _play(GameState state, UnoCard card) {
    final color = card.isWild ? _chooseColor(state) : null;
    state.playCard(state.currentPlayer.id, card, chosenColor: color);
  }

  /// Ưu tiên đánh lá không phải Wild trước (giữ Wild để dùng lúc bí).
  static UnoCard _chooseCard(List<UnoCard> playable) {
    final nonWild = playable.where((c) => !c.isWild).toList();
    final pool = nonWild.isNotEmpty ? nonWild : playable;
    return pool.first;
  }

  /// Chọn màu cho lá Wild = màu xuất hiện nhiều nhất trên tay bot.
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
