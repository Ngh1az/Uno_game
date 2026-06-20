import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/game_state.dart';
import '../../models/uno_card.dart';
import '../../models/uno_player.dart';
import '../../online/online_game_controller.dart';
import '../../titles/title_store.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/uno_card_widget.dart';
import '../../widgets/uno_circle_button.dart';

/// Màn hình phòng online: tự chuyển giữa "sảnh chờ" và "bàn chơi" theo trạng thái.
class RoomScreen extends StatefulWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final OnlineGameController _c;
  bool _winShown = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _c = OnlineGameController(code: widget.code)..start();
    _c.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    if (_c.error != null && _c.error != _lastError) {
      _lastError = _c.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnack.error(context, _c.error!);
        _c.clearError();
      });
    }
    if (_c.isFinished && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
    if (_c.isPlaying) _winShown = false;
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.leave();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _c.room;
    Widget body;
    if (room == null) {
      body = _centered(
        _c.roomClosed ? 'Phòng đã đóng.' : 'Đang kết nối...',
        showSpinner: !_c.roomClosed,
      );
    } else if (_c.isWaiting) {
      body = _waitingView();
    } else {
      body = _tableView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D3311),
      body: SafeArea(child: body),
    );
  }

  Widget _centered(String text, {bool showSpinner = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Về sảnh'),
          ),
        ],
      ),
    );
  }

  // ---------- Sảnh chờ ----------

  Widget _waitingView() {
    final room = _c.room!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              UnoCircleButton(
                icon: Icons.arrow_back,
                label: '',
                showLabel: false,
                size: 44,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Phòng chờ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Mã phòng', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              AppSnack.info(
                context,
                'Đã sao chép mã phòng',
                icon: Icons.content_copy_rounded,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Người chơi (${room.players.length}/${room.maxPlayers})',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final p in room.players)
                  Card(
                    color: Colors.black26,
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.white),
                      title: Text(
                        p.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: p.id == room.hostId
                          ? const Text(
                              'Chủ phòng',
                              style: TextStyle(color: Color(0xFFFFC107)),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          if (_c.isHost)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: room.players.length >= 2 ? _c.startGame : null,
                child: Text(
                  room.players.length >= 2
                      ? 'Bắt đầu'
                      : 'Cần ít nhất 2 người',
                ),
              ),
            )
          else
            const Text(
              'Đang chờ chủ phòng bắt đầu...',
              style: TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  // ---------- Bàn chơi ----------

  Widget _tableView() {
    final game = _c.game!;
    final meId = _c.uid;
    final opponents = game.players.where((p) => p.id != meId).toList();
    final me = game.players.firstWhere(
      (p) => p.id == meId,
      orElse: () => game.players.first,
    );

    return Column(
      children: [
        _topBar(game),
        _opponentsRow(game, opponents),
        Expanded(child: _centerArea(game)),
        _statusLine(game),
        _myHand(me),
      ],
    );
  }

  Widget _topBar(GameState game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          UnoCircleButton(
            icon: Icons.arrow_back,
            label: '',
            showLabel: false,
            size: 44,
            onTap: () => Navigator.of(context).pop(),
          ),
          Text(
            'Phòng ${_c.code}',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Icon(
            game.direction == PlayDirection.clockwise
                ? Icons.rotate_right
                : Icons.rotate_left,
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          const Text('Màu: ', style: TextStyle(color: Colors.white70)),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: unoColor(game.activeColor),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _opponentsRow(GameState game, List<UnoPlayer> opponents) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 6,
        children: [
          for (final p in opponents) _opponentTile(game, p),
        ],
      ),
    );
  }

  Widget _opponentTile(GameState game, UnoPlayer p) {
    final isTurn = game.currentPlayer.id == p.id;
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
            p.name,
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
                  '${p.hand.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        if (p.hasUno)
          const Text(
            'UNO!',
            style: TextStyle(
              color: Color(0xFFFFC107),
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _centerArea(GameState game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: (_c.isMyTurn && !game.drawnThisTurn) ? _c.drawCard : null,
              child: const UnoCardBack(width: 60),
            ),
            const SizedBox(height: 4),
            Text(
              'Rút (${game.drawPile.length})',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 28),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnoCardWidget(card: game.topCard, width: 72),
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

  Widget _statusLine(GameState game) {
    String text;
    if (game.status == GameStatus.finished) {
      text = 'Ván kết thúc';
    } else if (_c.isMyTurn) {
      text = _c.canPass ? 'Đến lượt bạn — đánh hoặc qua lượt' : 'Đến lượt bạn';
    } else {
      text = 'Lượt của ${game.currentPlayer.name}';
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
          if (_c.canPass) ...[
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _c.passTurn,
              child: const Text('Qua lượt'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _myHand(UnoPlayer me) {
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
              'Bài của bạn (${me.hand.length})',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: me.hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final card = me.hand[i];
                final playable = _c.canPlay(card);
                return Opacity(
                  opacity: playable || !_c.isMyTurn ? 1 : 0.55,
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

  Future<void> _onCardTap(UnoCard card) async {
    if (!_c.canPlay(card)) {
      AppSnack.warning(
        context,
        'Không thể đánh lá này / chưa tới lượt',
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    CardColor? chosen;
    if (card.isWild) {
      chosen = await _pickColor();
      if (chosen == null) return;
    }
    await _c.playCard(card, chosenColor: chosen);
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
    final game = _c.game;
    if (game == null || game.winnerId == null) return;
    final winner = game.players.firstWhere((p) => p.id == game.winnerId);
    final iWon = winner.id == _c.uid;
    if (iWon) TitleStore.instance.recordOnlineWin();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(iWon ? '🎉 Bạn thắng!' : 'Kết thúc'),
        content: Text(
          iWon ? 'Chúc mừng, bạn đã hết bài!' : '${winner.name} đã thắng.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Về sảnh'),
          ),
          if (_c.isHost)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _c.startGame();
              },
              child: const Text('Chơi lại'),
            ),
        ],
      ),
    );
  }
}
