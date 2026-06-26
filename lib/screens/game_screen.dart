import 'dart:async';

import 'package:flutter/material.dart';

import '../notifications/in_app_notifications.dart';
import '../app_settings.dart';
import '../daily_quests/daily_quest_store.dart';
import '../titles/title_store.dart';
import '../game/game_controller.dart';
import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../models/uno_player.dart';
import '../widgets/app_snack.dart';
import '../widgets/game/game_match_intro.dart';
import '../widgets/game/game_card_motion.dart';
import '../widgets/game/game_center_piles.dart';
import '../widgets/game/game_event_feedback.dart';
import '../widgets/game/game_hand_layout.dart';
import '../widgets/game/game_opponent_chip.dart';
import '../widgets/game/game_opponent_row.dart';
import '../widgets/game/game_premium_dialog.dart';
import '../widgets/game/game_status_bar.dart';
import '../widgets/game/game_player_hand_strip.dart';
import '../widgets/game/game_table_header.dart';
import '../widgets/game/game_table_shell.dart';
import '../widgets/game/game_theme.dart';
import '../widgets/game/opponent_chip_density.dart';
import '../widgets/settings_sheet.dart';

/// Bàn chơi UNO offline — premium đỏ–vàng, dùng chung Game Table Kit.
class GameScreen extends StatefulWidget {
  final int botCount;
  const GameScreen({super.key, required this.botCount});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  static const _compactBotThreshold = 4;

  late final GameController _controller;
  final _eventFeedback = GameEventFeedback();
  final _discardKey = GlobalKey();
  final _drawKey = GlobalKey();
  final _introHandKey = GlobalKey();
  final _handKey = GlobalKey();
  final _motionKey = GlobalKey<GameCardMotionLayerState>();
  final _drawFlyKey = GlobalKey();
  final _intro = GameMatchIntroController();
  final _handCounts = <String, int>{};
  bool _winShown = false;
  bool _playQuestRecorded = false;
  bool _suppressPlayAnim = false;
  bool _suppressDrawAnim = false;
  bool _introSeqRunning = false;
  int? _selectedHandIndex;
  bool _wasHumanTurn = false;
  bool _away = false;
  int _handResetToken = 0;

  GameCardMotionLayerState? get _motion => _motionKey.currentState;
  bool get _introBlocksPlay => _intro.blocksInteraction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = GameController();
    _controller.addListener(_onChange);
    _intro.addListener(_onIntroChange);
    _eventFeedback.reset();
    _controller.startGame(botCount: widget.botCount, runBots: false);
    final game = _controller.state;
    final fp = GameMatchIntroController.fingerprint(game);
    _intro.begin(fp, game.players.map((p) => p.id).toList());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startMatchIntro(game, fp));
    });
  }

  void _onIntroChange() {
    if (_intro.isDone) {
      _resetHandUiState();
      _handResetToken++;
    }
    if (mounted) setState(() {});
  }

  void _resetHandUiState() {
    _selectedHandIndex = null;
    _suppressPlayAnim = false;
    _suppressDrawAnim = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _away = state != AppLifecycleState.resumed;
  }

  Future<void> _startMatchIntro(GameState game, String fp) async {
    if (_intro.hasCompleted(fp) || _introSeqRunning) return;

    _introSeqRunning = true;
    _resetHandUiState();
    if (!_intro.isActive || _intro.activeFingerprint != fp) {
      _intro.begin(fp, game.players.map((p) => p.id).toList());
    }
    _snapshotHands(game);

    try {
      await GameMatchIntroRunner.runCountdown(_intro);
      if (!mounted || _intro.isDone) return;

      if (_useCardMotion) {
        _intro.setDealing();
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || _intro.isDone) return;
        final pileW = GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width);
        await GameMatchIntroRunner.runDealSequence(
          motion: _motion,
          controller: _intro,
          game: game,
          myUid: GameController.humanId,
          drawKey: _drawFlyKey,
          handKey: _introHandKey,
          opponentKeys: const {},
          pileWidth: pileW,
          viewportWidth: MediaQuery.sizeOf(context).width,
        );
        if (!mounted || _intro.isDone) return;
        await GameMatchIntroRunner.runStarterReveal(
          motion: _motion,
          starterCard: game.topCard,
          drawKey: _drawFlyKey,
          pileWidth: pileW,
        );
      }

      if (!mounted) return;
      if (!_intro.isDone) _intro.markDone();
      _resetHandUiState();
      _controller.resumeBots();
    } finally {
      _introSeqRunning = false;
      if (mounted) setState(() {});
    }
  }

  void _onChange() {
    if (!mounted) return;
    _eventFeedback.onLogChanged(context, _controller.state.log);
    _detectOpponentMotion(_controller.state);

    if (_controller.isFinished && !_playQuestRecorded) {
      _playQuestRecorded = true;
      DailyQuestStore.instance.markOfflinePlay();
      TitleStore.instance.recordOfflinePlay();
    }

    if (_controller.isFinished && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinDialog();
      });
    }
    if (!_controller.isHumanTurn) {
      _selectedHandIndex = null;
      _wasHumanTurn = false;
    } else if (_intro.isDone && !_introBlocksPlay) {
      final away = _away || InAppNotifications.appInBackground;
      if (away && !_wasHumanTurn) {
        final state = _controller.state;
        final turnKey =
            'offline-${state.log.length}-${state.currentPlayer.id}';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          InAppNotifications.notifyMyTurn(context, turnKey: turnKey);
        });
      }
      _wasHumanTurn = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChange);
    _intro.removeListener(_onIntroChange);
    _controller.dispose();
    super.dispose();
  }

  bool get _showHints => AppSettings.instance.showPlayableHints;

  bool get _useCardMotion => AppSettings.instance.cardAnimations;

  void _snapshotHands(GameState state) {
    _handCounts
      ..clear()
      ..addEntries(state.players.map((p) => MapEntry(p.id, p.hand.length)));
  }

  void _detectOpponentMotion(GameState state) {
    if (_introBlocksPlay) return;

    if (_handCounts.isEmpty) {
      _snapshotHands(state);
      return;
    }

    for (final player in state.players) {
      final prev = _handCounts[player.id] ?? player.hand.length;
      if (player.hand.length == prev - 1 && !_suppressPlayAnim) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _animateOpponentPlay(player, state.topCard);
        });
        break;
      }
      if (player.hand.length == prev + 1 &&
          player.id != GameController.humanId &&
          !_suppressDrawAnim) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _animateOpponentDraw(player);
        });
        break;
      }
    }

    _suppressPlayAnim = false;
    _suppressDrawAnim = false;
    _snapshotHands(state);
  }

  Future<void> _animateOpponentPlay(UnoPlayer player, UnoCard card) async {
    final motion = _useCardMotion ? _motion : null;
    if (motion == null) return;

    final from = _seatCenter(player);
    final to = GameCardMotionLayerState.centerOf(_discardKey);
    await motion.fly(
      card: card,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width),
    );
  }

  Future<void> _animateOpponentDraw(UnoPlayer player) async {
    final motion = _useCardMotion ? _motion : null;
    if (motion == null) return;

    final from = GameCardMotionLayerState.centerOf(_drawKey);
    final to = _seatCenter(player);
    await motion.fly(
      card: _controller.state.topCard,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width),
      faceDown: true,
      duration: const Duration(milliseconds: 320),
    );
  }

  Offset _seatCenter(UnoPlayer player) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + 88;
    if (player.isBot) {
      final bots = _controller.state.players.where((p) => p.isBot).toList();
      final index = bots.indexWhere((b) => b.id == player.id);
      if (index >= 0 && bots.length >= _compactBotThreshold) {
        final rowW = size.width - 32;
        final chipW = OpponentChipDensityX.forBotCount(bots.length).botChipWidth;
        final gap = 8.0;
        final stride = chipW + gap;
        final totalW = bots.length * chipW + (bots.length - 1) * gap;
        final startX = (rowW - totalW) / 2 + 16;
        final x = startX + index * stride + chipW / 2;
        return Offset(x, top + 28);
      }
    }
    return Offset(size.width / 2, top);
  }

  Future<void> _drawAnimated() async {
    if (_introBlocksPlay) return;
    if (!_controller.isHumanTurn || _controller.botThinking) return;

    final state = _controller.state;
    if (state.mustRespondToDrawStack) {
      _controller.acceptDrawStack();
      return;
    }
    if (state.drawnThisTurn) return;

    final motion = _useCardMotion ? _motion : null;
    if (motion == null) {
      _controller.drawHuman();
      return;
    }

    final screenSize = MediaQuery.sizeOf(context);
    await WidgetsBinding.instance.endOfFrame;
    final from = GameCardMotionLayerState.centerOf(_drawKey);
    final to = GameCardMotionLayerState.centerOf(
      _handKey,
      fallback: Offset(
        screenSize.width / 2,
        screenSize.height - 120,
      ),
    );

    _suppressDrawAnim = true;
    await motion.fly(
      card: _controller.state.topCard,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(screenSize.width),
      faceDown: true,
      duration: const Duration(milliseconds: 400),
    );
    if (!mounted) return;
    _controller.drawHuman();
  }

  Future<void> _playCardAnimated(
    UnoCard card, {
    CardColor? chosenColor,
    Offset? fromGlobal,
  }) async {
    if (_introBlocksPlay) return;
    final index = _controller.human.hand.indexWhere((c) => c == card);
    if (index < 0) return;

    _selectedHandIndex = null;

    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: _controller.human.hand.length,
    );
    final motion = _useCardMotion ? _motion : null;
    final from = fromGlobal ?? GameCardMotionLayerState.centerOf(_handKey);

    try {
      if (motion != null) {
        _suppressPlayAnim = true;
        final to = GameCardMotionLayerState.centerOf(_discardKey);
        await motion.fly(
          card: card,
          from: from,
          to: to,
          width: layout.cardWidth,
        );
        if (!mounted) return;
      } else {
        _suppressPlayAnim = true;
      }

      _controller.playHuman(card, chosenColor: chosenColor, handIndex: index);
      if (mounted) setState(() => _selectedHandIndex = null);
    } finally {
      _selectedHandIndex = null;
    }
  }

  void _selectCard(int handIndex) {
    final hand = _controller.human.hand;
    if (handIndex < 0 || handIndex >= hand.length) return;
    final card = hand[handIndex];
    if (!_controller.canPlay(card)) {
      AppSnack.warning(context, 'Không thể chọn lá này',
          duration: const Duration(milliseconds: 900));
      return;
    }
    setState(() => _selectedHandIndex = handIndex);
  }

  Future<void> _playSelected({Offset? fromGlobal}) async {
    final hand = _controller.human.hand;
    final handIndex = _selectedHandIndex;
    if (handIndex == null || handIndex < 0 || handIndex >= hand.length) {
      AppSnack.warning(context, 'Chọn lá bài trước',
          duration: const Duration(milliseconds: 900));
      return;
    }
    final card = hand[handIndex];
    if (!_controller.canPlay(card)) {
      setState(() => _selectedHandIndex = null);
      return;
    }
    CardColor? chosen;
    if (card.isWild) {
      chosen = await GamePremiumDialog.pickColor(context);
      if (chosen == null) return;
    }
    await _playCardAnimated(card, chosenColor: chosen, fromGlobal: fromGlobal);
  }

  void _callUno() {
    _controller.callUno();
    AppSnack.success(context, 'UNO!', icon: Icons.campaign_rounded);
  }

  void _catchUno(String targetId) {
    _controller.catchUno(targetId);
  }

  void _showWinDialog() {
    if (!mounted) return;
    final state = _controller.state;
    final winner = state.players.firstWhere((p) => p.id == state.winnerId);
    final youWon = winner.id == GameController.humanId;
    if (youWon) {
      DailyQuestStore.instance.markOfflineWin();
      TitleStore.instance.recordOfflineWin();
    }
    GamePremiumDialog.showWin(
      context: context,
      youWon: youWon,
      winnerName: winner.name,
      leaveLabel: 'Về menu',
      onLeave: () => Navigator.of(context).pop(),
      replayLabel: 'Chơi lại',
      onReplay: () {
        setState(() {
          _winShown = false;
          _playQuestRecorded = false;
        });
        _eventFeedback.reset();
        _handCounts.clear();
        _intro.reset();
        _resetHandUiState();
        _controller.startGame(botCount: widget.botCount, runBots: false);
        final replayGame = _controller.state;
        final fp = GameMatchIntroController.fingerprint(replayGame);
        _intro.begin(fp, replayGame.players.map((p) => p.id).toList());
        unawaited(_startMatchIntro(replayGame, fp));
      },
    );
  }

  Future<void> _confirmLeave() async {
    final leave = await GamePremiumDialog.confirmLeave(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = _controller.state;
    final bots = state.players.where((p) => p.isBot).toList();
    final humanTurn =
        _controller.isHumanTurn && !_controller.botThinking && !_introBlocksPlay;
    final settings = AppSettings.instance;
    final human = _controller.human;
    final catchableId = state.catchableUnoPlayerId;
    UnoPlayer? catchablePlayer;
    if (catchableId != null) {
      for (final p in state.players) {
        if (p.id == catchableId) {
          catchablePlayer = p;
          break;
        }
      }
    }
    final showUno = humanTurn &&
        !settings.autoUnoCall &&
        !state.hasDeclaredUno(GameController.humanId) &&
        (human.hand.length == 2 ||
            (human.hand.length == 1 &&
                catchableId != GameController.humanId));
    final showCatch = catchableId != null &&
        catchableId != GameController.humanId &&
        !_introBlocksPlay;
    final statusLabel = _intro.phase == GameMatchIntroPhase.dealing
        ? 'Đang chia bài...'
        : _intro.phase == GameMatchIntroPhase.countdown
            ? 'Chuẩn bị...'
            : humanTurn
                ? 'Lượt của bạn'
                : 'Lượt ${_controller.state.currentPlayer.name}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave();
      },
      child: Scaffold(
        body: GameCardMotionLayer(
          key: _motionKey,
          child: GameTableShell(
            child: SafeArea(
              child: AbsorbPointer(
                absorbing: _introBlocksPlay,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        GameTableHeader(
                          game: state,
                          onBack: _confirmLeave,
                          onSettings: () => SettingsSheet.show(context),
                        ),
                        Expanded(child: _arena(state, bots)),
                        GameStatusBar(
                          isMyTurn: humanTurn,
                          turnLabel: statusLabel,
                          canPass: _controller.canPass && !_introBlocksPlay,
                          onPass: _controller.passHuman,
                          showUnoButton: showUno,
                          onUno: _callUno,
                          showCatchUnoButton: showCatch,
                          catchUnoLabel: catchablePlayer == null
                              ? 'Bắt UNO'
                              : 'Bắt ${catchablePlayer.name}',
                          onCatchUno: catchableId == null
                              ? null
                              : () => _catchUno(catchableId),
                          drawStackCount: humanTurn
                              ? state.pendingDrawCount
                              : 0,
                        ),
                        const SizedBox(height: 6),
                        _handSection(state),
                        const SizedBox(height: 12),
                      ],
                    ),
                    GameMatchIntroOverlay(
                      label: _intro.countdownLabel,
                      visible: _intro.phase == GameMatchIntroPhase.countdown,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arena(GameState state, List<UnoPlayer> bots) {
    final humanTurn = _controller.isHumanTurn &&
        !_controller.botThinking &&
        !_introBlocksPlay;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 8,
          bottom: 20,
          child: _botArc(state, bots),
        ),
        Center(
          child: GameCenterPiles(
            topCard: state.topCard,
            activeColor: state.activeColor,
            canDraw: humanTurn &&
                (state.mustRespondToDrawStack || !state.drawnThisTurn),
            onDraw: _drawAnimated,
            drawPileCount: state.drawPile.length,
            discardKey: _discardKey,
            drawKey: _drawKey,
            drawFlyKey: _drawFlyKey,
            discardCount: state.discardPile.length,
            hideDiscard: _introBlocksPlay,
          ),
        ),
      ],
    );
  }

  Widget _botArc(GameState state, List<UnoPlayer> bots) {
    final density = OpponentChipDensityX.forBotCount(bots.length);

    if (bots.length >= _compactBotThreshold) {
      final activeIndex = bots.indexWhere(
        (b) => b.id == state.currentPlayer.id,
      );

      return Align(
        alignment: Alignment.topCenter,
        child: GameOpponentRow(
          itemCount: bots.length,
          activeIndex: activeIndex < 0 ? 0 : activeIndex,
          density: density,
          botOnly: true,
          itemBuilder: (context, i) {
            final bot = bots[i];
            final catchable = state.catchableUnoPlayerId == bot.id;
            return GameOpponentChip(
              player: bot,
              isTurn: !_introBlocksPlay && state.currentPlayer.id == bot.id,
              isBot: true,
              density: density,
              thinking: _controller.botThinking &&
                  state.currentPlayer.id == bot.id,
              cardCountOverride: _intro.virtualHandCounts[bot.id],
              catchableUno: catchable,
              onCatchUno: catchable ? () => _catchUno(bot.id) : null,
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < bots.length; i++)
              _arcSeat(
                index: i,
                count: bots.length,
                width: w,
                height: h,
                child: GameOpponentChip(
                  player: bots[i],
                  isTurn: !_introBlocksPlay &&
                      state.currentPlayer.id == bots[i].id,
                  isBot: true,
                  density: density,
                  thinking: _controller.botThinking &&
                      state.currentPlayer.id == bots[i].id,
                  cardCountOverride: _intro.virtualHandCounts[bots[i].id],
                  catchableUno: state.catchableUnoPlayerId == bots[i].id,
                  onCatchUno: state.catchableUnoPlayerId == bots[i].id
                      ? () => _catchUno(bots[i].id)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _arcSeat({
    required int index,
    required int count,
    required double width,
    required double height,
    required Widget child,
  }) {
    final useTwoRows = count > 5;
    final topCount = useTwoRows ? (count + 1) ~/ 2 : count;
    final isTopRow = !useTwoRows || index < topCount;
    final rowIndex = isTopRow ? index : index - topCount;
    final rowCount = isTopRow ? topCount : count - topCount;

    final t = rowCount == 1 ? 0.0 : (rowIndex / (rowCount - 1)) * 2 - 1;
    final spread = count > 7 ? 0.48 : 0.42;
    final x = width * 0.5 + t * width * spread;
    final y = isTopRow
        ? height * 0.02 + t.abs() * height * 0.03
        : height * 0.16 + t.abs() * height * 0.02;
    final chipW = count > 7 ? 80.0 : 92.0;

    return Positioned(
      left: x - chipW / 2,
      top: y,
      width: chipW,
      child: child,
    );
  }

  Widget _handSection(GameState state) {
    if (_introBlocksPlay) {
      final virtualCount = _intro.virtualHandCounts[GameController.humanId] ?? 0;
      return GameIntroHandStrip(
        handKey: _introHandKey,
        cardCount: virtualCount,
        viewportWidth: MediaQuery.sizeOf(context).width,
      );
    }

    final humanTurn = _controller.isHumanTurn && !_controller.botThinking;
    final hand = _controller.human.hand;
    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: hand.length,
    );
    final handFp = _intro.activeFingerprint ??
        GameMatchIntroController.fingerprint(state);

    return SizedBox(
      key: _handKey,
      height: layout.totalHeight(hand.length),
      width: double.infinity,
      child: GamePlayerHandStrip(
        key: ValueKey('hand-$handFp-${hand.length}'),
        resetToken: _handResetToken,
        cards: hand,
        isMyTurn: humanTurn,
        showHints: _showHints,
        canPlay: _controller.canPlay,
        selectedIndex: _selectedHandIndex,
        onCardTap: (card, index, globalCenter) {
          if (_selectedHandIndex == index) {
            unawaited(_playSelected(fromGlobal: globalCenter));
          } else {
            _selectCard(index);
          }
        },
      ),
    );
  }
}
