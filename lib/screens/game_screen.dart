import 'package:flutter/material.dart';

import '../daily_quests/daily_quest_store.dart';
import '../titles/title_store.dart';
import '../game/game_controller.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import '../widgets/app_snack.dart';
import '../widgets/uno_card_widget.dart';

/// Bàn chơi UNO (người thật vs bot).
class GameScreen extends StatefulWidget {
  final int botCount;
  const GameScreen({super.key, required this.botCount});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  bool _winShown = false;

  @override
  void initState() {
    super.initState();
    DailyQuestStore.instance.markOfflinePlay();
    TitleStore.instance.recordOfflinePlay();
    _controller = GameController()..startGame(botCount: widget.botCount);
    _controller.addListener(_onChange);
  }

  void _onChange() {
    if (_controller.isFinished && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCardTap(UnoCard card) async {
    if (!_controller.canPlay(card)) {
      AppSnack.warning(
        context,
        'Không thể đánh lá này',
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    CardColor? chosen;
    if (card.isWild) {
      chosen = await _pickColor();
      if (chosen == null) return; // người chơi huỷ
    }
    _controller.playHuman(card, chosenColor: chosen);
  }

  Future<CardColor?> _pickColor() {
    return showDialog<CardColor>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn màu'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in [
              CardColor.red,
              CardColor.yellow,
              CardColor.green,
              CardColor.blue,
            ])
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(c),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: unoColor(c),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unoColorName(c),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showWinDialog() {
    final state = _controller.state;
    final winner = state.players.firstWhere((p) => p.id == state.winnerId);
    final youWon = winner.id == GameController.humanId;
    if (youWon) {
      DailyQuestStore.instance.markOfflineWin();
      TitleStore.instance.recordOfflineWin();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(youWon ? '🎉 Bạn thắng!' : 'Kết thúc'),
        content: Text(
          youWon ? 'Chúc mừng, bạn đã hết bài!' : '${winner.name} đã thắng.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // về menu
            },
            child: const Text('Về menu'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _winShown = false);
              _controller.startGame(botCount: widget.botCount);
            },
            child: const Text('Chơi lại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final bots = state.players.where((p) => p.isBot).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 1.0,
            colors: [Color(0xFF2E7D32), Color(0xFF0D3311)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(state),
              _opponentsRow(state, bots),
              Expanded(child: _centerArea(state)),
              _statusLine(state),
              _humanHand(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Icon(
            state.direction == PlayDirection.clockwise
                ? Icons.rotate_right
                : Icons.rotate_left,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          const Text('Chiều', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 16),
          const Text('Màu: ', style: TextStyle(color: Colors.white70)),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: unoColor(state.activeColor),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _opponentsRow(GameState state, List<UnoPlayer> bots) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 6,
        children: [
          for (final bot in bots) _opponentTile(state, bot),
        ],
      ),
    );
  }

  Widget _opponentTile(GameState state, UnoPlayer bot) {
    final isTurn = state.currentPlayer.id == bot.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isTurn ? const Color(0xFFFFC107) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            bot.name,
            style: TextStyle(
              color: isTurn ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const UnoCardBack(width: 32),
            Positioned(
              right: -6,
              top: -6,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.red,
                child: Text(
                  '${bot.hand.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        if (bot.hasUno)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'UNO!',
              style: TextStyle(
                color: Color(0xFFFFC107),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _centerArea(GameState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Chồng bài rút
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _controller.isHumanTurn && !_controller.botThinking
                  ? _controller.drawHuman
                  : null,
              child: const UnoCardBack(width: 60),
            ),
            const SizedBox(height: 4),
            Text(
              'Rút (${state.drawPile.length})',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 28),
        // Lá trên cùng
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnoCardWidget(card: state.topCard, width: 72),
            const SizedBox(height: 4),
            const Text(
              'Đã đánh',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusLine(GameState state) {
    String text;
    if (state.status == GameStatus.finished) {
      text = 'Ván kết thúc';
    } else if (_controller.botThinking) {
      text = '${state.currentPlayer.name} đang suy nghĩ...';
    } else if (_controller.isHumanTurn) {
      text = _controller.canPass
          ? 'Đến lượt bạn — đánh hoặc qua lượt'
          : 'Đến lượt bạn';
    } else {
      text = 'Lượt của ${state.currentPlayer.name}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_controller.canPass) ...[
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _controller.passHuman,
              child: const Text('Qua lượt'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _humanHand(GameState state) {
    final human = _controller.human;
    return Container(
      height: 116,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Bài của bạn (${human.hand.length})',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: human.hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final card = human.hand[i];
                final playable = _controller.canPlay(card);
                return Opacity(
                  opacity: playable || !_controller.isHumanTurn ? 1 : 0.55,
                  child: Transform.translate(
                    offset: Offset(0, playable ? -10 : 0),
                    child: UnoCardWidget(
                      card: card,
                      width: 54,
                      onTap: () => _onCardTap(card),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
