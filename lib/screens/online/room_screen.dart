import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../daily_quests/daily_quest_store.dart';
import '../../friends/friends_service.dart';
import '../../friends/presence_service.dart';
import '../../models/game_state.dart';
import '../../models/uno_card.dart';
import '../../models/uno_player.dart';
import '../../online/online_game_controller.dart';
import '../../online/turn_timeout_watcher.dart';
import '../../game/game_limits.dart';
import '../../game/turn_timeout_policy.dart';
import '../../online/waiting_room_session.dart';
import '../../titles/title_store.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/game/game_match_intro.dart';
import '../../widgets/game/game_card_motion.dart';
import '../../widgets/game/game_center_piles.dart';
import '../../widgets/game/game_event_feedback.dart';
import '../../widgets/game/game_hand_layout.dart';
import '../../widgets/game/game_opponent_chip.dart';
import '../../widgets/game/game_opponent_row.dart';
import '../../widgets/game/game_player_hand_strip.dart';
import '../../widgets/game/game_premium_dialog.dart';
import '../../widgets/game/game_status_bar.dart';
import '../../widgets/game/game_table_header.dart';
import '../../widgets/game/game_table_shell.dart';
import '../../widgets/game/game_theme.dart';
import '../../widgets/invite_friends_sheet.dart';
import '../../widgets/room_players_sheet.dart';
import '../../widgets/game/opponent_chip_density.dart';
import '../../online/room.dart';
import '../../online/room_service.dart';
import '../../widgets/settings_sheet.dart';
import 'waiting_room_lobby.dart';
class RoomScreen extends StatefulWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final OnlineGameController _c;
  final _eventFeedback = GameEventFeedback();
  final _discardKey = GlobalKey();
  final _drawKey = GlobalKey();
  final _drawFlyKey = GlobalKey();
  final _introHandKey = GlobalKey();
  final _handKey = GlobalKey();
  final _motionKey = GlobalKey<GameCardMotionLayerState>();
  final _handCounts = <String, int>{};
  final _intro = GameMatchIntroController();
  final _opponentKeys = <String, GlobalKey>{};
  bool _winShown = false;
  bool _playQuestRecorded = false;
  bool _suppressPlayAnim = false;
  bool _suppressDrawAnim = false;
  bool _introSeqRunning = false;
  int? _selectedHandIndex;
  String? _lastError;
  RoomStatus? _lastRoomStatus;
  int? _introBaselineLogLength;
  String? _introBaselineTopCard;
  bool _kickedHandled = false;
  int _handResetToken = 0;
  late final TurnTimeoutWatcher _timeoutWatcher;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _c = WaitingRoomSession.instance.bind(widget.code);
    _timeoutWatcher = TurnTimeoutWatcher(controller: _c);
    _timeoutWatcher.start();
    _countdownTimer = Timer.periodic(TurnTimeoutPolicy.countdownTick, (_) {
      if (mounted && _c.isPlaying) setState(() {});
    });
    WaitingRoomSession.instance.setRoomScreenVisible(true);
    _c.addListener(_onChange);
    _intro.addListener(_onIntroChange);
    _eventFeedback.reset();
    _lastRoomStatus = _c.room?.status;
    if (_c.isPlaying && _c.game != null) {
      _intro.markCompleted(GameMatchIntroController.fingerprint(_c.game!));
      _snapshotHands(_c.game!);
    }
    final uid = _c.uid;
    if (uid.isNotEmpty) {
      unawaited(PresenceService.instance.start(uid));
    }
    unawaited(FriendsService().warmFriendsCache());
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

    final game = _c.game;
    final status = _c.room?.status;

    if (_c.room != null && !_c.isMember) {
      if (WaitingRoomSession.instance.leavingVoluntarily) return;
      if (!_kickedHandled) {
        _kickedHandled = true;
        _winShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_handleKicked());
        });
      }
      return;
    }

    if (game != null && _c.isPlaying) {
      if (_intro.blocksInteraction) {
        _checkIntroFastForward(game);
      }
      if (_intro.isDone && _c.isMember) {
        _eventFeedback.onLogChanged(context, game.log);
        _detectCardMotion(game);
      }
    } else if (game != null && _c.isMember) {
      _eventFeedback.onLogChanged(context, game.log);
    }

    if (status == RoomStatus.playing && game != null) {
      final shouldTrigger = _lastRoomStatus == RoomStatus.waiting ||
          _lastRoomStatus == RoomStatus.finished;
      if (shouldTrigger) {
        _playQuestRecorded = false;
        _winShown = false;
        _resetHandUiState();
        final fp = GameMatchIntroController.fingerprint(game);
        if (!_intro.hasCompleted(fp) && !_introSeqRunning) {
          _intro.begin(fp, game.players.map((p) => p.id).toList());
          _introBaselineLogLength = game.log.length;
          _introBaselineTopCard = game.topCard.label;
        }
        unawaited(_maybeStartIntro(game));
      }
    }
    _lastRoomStatus = status ?? _lastRoomStatus;

    if (_c.isFinished && !_playQuestRecorded && _c.isMember) {
      _playQuestRecorded = true;
      DailyQuestStore.instance.markOnlinePlay();
      TitleStore.instance.recordOnlinePlay();
    }

    if (_c.isFinished && !_winShown && _c.isMember) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinDialog();
      });
    }
    if (_c.isPlaying) {
      _winShown = false;
      if (!_c.isMyTurn) _selectedHandIndex = null;
    }
    setState(() {});
  }

  void _checkIntroFastForward(GameState game) {
    final baseLog = _introBaselineLogLength;
    if (baseLog != null && game.log.length > baseLog) {
      _intro.fastForward();
      _resetHandUiState();
      return;
    }
    final baseTop = _introBaselineTopCard;
    if (baseTop != null && game.topCard.label != baseTop) {
      _intro.fastForward();
      _resetHandUiState();
    }
  }

  Future<void> _maybeStartIntro(GameState game) async {
    final fp = GameMatchIntroController.fingerprint(game);
    if (_intro.hasCompleted(fp) || _introSeqRunning) return;

    if (WaitingRoomSession.instance.gameStartedWhileMinimized) {
      WaitingRoomSession.instance.clearGameStartedFlag();
      _intro.markCompleted(fp);
      _resetHandUiState();
      _snapshotHands(game);
      return;
    }

    await _startMatchIntro(game, fp);
  }

  Future<void> _startMatchIntro(GameState game, String fp) async {
    if (_introSeqRunning) return;
    _introSeqRunning = true;

    _resetHandUiState();
    if (!_intro.isActive || _intro.activeFingerprint != fp) {
      _intro.begin(fp, game.players.map((p) => p.id).toList());
      _introBaselineLogLength = game.log.length;
      _introBaselineTopCard = game.topCard.label;
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
          myUid: _c.uid,
          drawKey: _drawFlyKey,
          handKey: _introHandKey,
          opponentKeys: _opponentKeysFor(game),
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
    } finally {
      _introSeqRunning = false;
      if (mounted) setState(() {});
    }
  }

  Map<String, GlobalKey> _opponentKeysFor(GameState game) {
    final meId = _c.uid;
    final map = <String, GlobalKey>{};
    for (final p in game.players) {
      if (p.id == meId) continue;
      map[p.id] = _opponentKeys.putIfAbsent(p.id, GlobalKey.new);
    }
    return map;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timeoutWatcher.dispose();
    if (WaitingRoomSession.instance.controller == _c) {
      _c.removeListener(_onChange);
    }
    _intro.removeListener(_onIntroChange);
    WaitingRoomSession.instance.setRoomScreenVisible(false);
    super.dispose();
  }

  bool get _introBlocksPlay => _intro.blocksInteraction;

  bool get _showHints => AppSettings.instance.showPlayableHints;

  bool get _useCardMotion => AppSettings.instance.cardAnimations;

  GameCardMotionLayerState? get _motion => _motionKey.currentState;

  void _snapshotHands(GameState state) {
    _handCounts
      ..clear()
      ..addEntries(state.players.map((p) => MapEntry(p.id, p.hand.length)));
  }

  void _detectCardMotion(GameState state) {
    if (_intro.blocksInteraction) return;

    if (_handCounts.isEmpty) {
      _snapshotHands(state);
      return;
    }

    for (final player in state.players) {
      final prev = _handCounts[player.id] ?? player.hand.length;
      if (player.hand.length == prev - 1 && !_suppressPlayAnim) {
        final isSelf = player.id == _c.uid;
        final card = state.topCard;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (isSelf) {
            setState(() => _selectedHandIndex = null);
            unawaited(_animateSelfPlay(card));
          } else {
            unawaited(_animateOpponentPlay(player, card));
          }
        });
        break;
      }
      if (player.hand.length == prev + 1 &&
          player.id != _c.uid &&
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

  Future<void> _animateSelfPlay(UnoCard card) async {
    final motion = _useCardMotion ? _motion : null;
    if (motion == null) return;

    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: _c.me?.hand.length ?? 1,
    );
    final from = GameCardMotionLayerState.centerOf(_handKey);
    final to = GameCardMotionLayerState.centerOf(_discardKey);
    await motion.fly(
      card: card,
      from: from,
      to: to,
      width: layout.cardWidth,
    );
  }

  Future<void> _animateOpponentPlay(UnoPlayer player, UnoCard card) async {
    final motion = _useCardMotion ? _motion : null;
    if (motion == null) return;

    final size = MediaQuery.sizeOf(context);
    final from = Offset(size.width / 2, MediaQuery.paddingOf(context).top + 100);
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

    final size = MediaQuery.sizeOf(context);
    final from = GameCardMotionLayerState.centerOf(_drawKey);
    final to = Offset(size.width / 2, MediaQuery.paddingOf(context).top + 100);
    await motion.fly(
      card: _c.game!.topCard,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width),
      faceDown: true,
      duration: const Duration(milliseconds: 320),
    );
  }

  Future<void> _drawAnimated() async {
    if (_introBlocksPlay) return;
    final game = _c.game;
    if (game == null || !_c.isMyTurn) return;

    if (game.mustRespondToDrawStack) {
      await _c.acceptDrawStack();
      return;
    }
    if (game.drawnThisTurn) return;

    final motion = _useCardMotion ? _motion : null;
    if (motion == null) {
      await _c.drawCard();
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
      card: game.topCard,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(screenSize.width),
      faceDown: true,
      duration: const Duration(milliseconds: 400),
    );
    if (!mounted) return;
    await _c.drawCard();
  }

  Future<void> _playCardAnimated(
    UnoCard card, {
    CardColor? chosenColor,
    required int handIndex,
    Offset? fromGlobal,
  }) async {
    final game = _c.game;
    if (game == null) return;

    final me = _c.me;
    if (me == null) return;

    if (handIndex < 0 || handIndex >= me.hand.length) return;

    _selectedHandIndex = null;

    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: me.hand.length,
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

      await _c.playCard(
        card,
        chosenColor: chosenColor,
        handIndex: handIndex,
        declaredUno: game.hasDeclaredUno(_c.uid),
        autoUno: AppSettings.instance.autoUnoCall,
      );
    } finally {
      _selectedHandIndex = null;
    }
  }

  Future<void> _callUno() async {
    await _c.callUno();
    if (!mounted) return;
    AppSnack.success(context, 'UNO!', icon: Icons.campaign_rounded);
  }

  Future<void> _catchUno(String targetId) async {
    await _c.catchUno(targetId);
  }

  Future<void> _confirmKick(String targetId, String targetName) async {
    final kick = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A0707),
        title: const Text(
          'Đuổi người chơi?',
          style: TextStyle(color: GameTheme.gold),
        ),
        content: Text(
          'Đuổi $targetName khỏi phòng?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đuổi',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
    if (kick != true || !mounted) return;
    try {
      await _c.kickPlayer(targetId);
      if (mounted) {
        AppSnack.info(context, 'Đã đuổi $targetName');
      }
    } catch (e) {
      if (mounted) {
        final msg = e is RoomException
            ? e.message
            : 'Không đuổi được người chơi.';
        AppSnack.error(context, msg);
      }
    }
  }

  Future<void> _confirmLeave({required bool inGame}) async {
    final leave = await GamePremiumDialog.confirmLeave(
      context,
      title: inGame ? 'Rời ván?' : 'Rời phòng?',
      message: inGame
          ? 'Bạn có chắc muốn thoát? Tiến trình ván hiện tại sẽ không được lưu.'
          : 'Bạn có chắc muốn rời phòng không?',
      confirmLabel: inGame ? 'Rời ván' : 'Rời phòng',
    );
    if (!leave || !mounted) return;
    try {
      await WaitingRoomSession.instance.leave();
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, 'Không rời được phòng. Thử lại.');
      }
      return;
    }
    _kickedHandled = true;
    if (mounted) Navigator.of(context).pop();
  }

  void _minimizeToHome() {
    WaitingRoomSession.instance.minimize();
    WaitingRoomSession.instance.setRoomScreenVisible(false);
    Navigator.of(context).popUntil((route) => route.isFirst);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_c.isPlaying) {
          await _confirmLeave(inGame: true);
        } else if (_c.isWaiting) {
          await _confirmLeave(inGame: false);
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: GameCardMotionLayer(
          key: _motionKey,
          child: GameTableShell(child: SafeArea(child: body)),
        ),
      ),
    );
  }

  Widget _centered(String text, {bool showSpinner = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            const CircularProgressIndicator(color: GameTheme.gold),
            const SizedBox(height: 16),
          ],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: GameTheme.gold,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Về sảnh'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlayersSheet() async {
    final room = _c.room;
    if (room == null) return;
    await RoomPlayersSheet.show(
      context,
      room: room,
      myUid: _c.uid,
      isHost: _c.isHost,
      game: _c.game,
      onKick: _c.isHost ? _confirmKick : null,
    );
  }

  Future<void> _openInviteFriends() async {
    if (!mounted) return;
    await InviteFriendsSheet.show(context, roomCode: widget.code);
  }

  Widget _waitingView() {
    final room = _c.room!;
    return WaitingRoomLobby(
      room: room,
      myUid: _c.uid,
      isHost: _c.isHost,
      onLeave: () => _confirmLeave(inGame: false),
      onMinimizeHome: _minimizeToHome,
      onInviteFriends: _openInviteFriends,
      onStartGame: _c.startGame,
    );
  }

  Widget _tableView() {
    final game = _c.game!;
    final room = _c.room!;
    final meId = _c.uid;
    final memberIds = room.players.map((p) => p.id).toSet();
    final opponents = game.players
        .where((p) => p.id != meId && memberIds.contains(p.id))
        .toList();
    final profiles = {for (final p in room.players) p.id: p};
    final density = OpponentChipDensityX.forOpponentCount(opponents.length);
    final me = _c.me;
    if (me == null) {
      return _centered('Bạn đã bị.');
    }
    final myTurn = _c.isMyTurn && !_introBlocksPlay;
    final settings = AppSettings.instance;
    final catchableId = game.catchableUnoPlayerId;
    UnoPlayer? catchablePlayer;
    if (catchableId != null) {
      for (final p in game.players) {
        if (p.id == catchableId) {
          catchablePlayer = p;
          break;
        }
      }
    }
    final showUno = myTurn &&
        !settings.autoUnoCall &&
        !game.hasDeclaredUno(meId) &&
        (me.hand.length == 2 ||
            (me.hand.length == 1 && catchableId != meId));
    final showCatch = catchableId != null &&
        catchableId != meId &&
        !_introBlocksPlay;
    final statusLabel = _c.isFinished
        ? 'Ván kết thúc'
        : _intro.phase == GameMatchIntroPhase.dealing
            ? 'Đang chia bài...'
            : _intro.phase == GameMatchIntroPhase.countdown
                ? 'Chuẩn bị...'
                : myTurn
                    ? 'Lượt của bạn'
                    : 'Lượt ${game.currentPlayer.name}';
    final turnSecs = _c.turnTimeRemaining?.inSeconds;

    return AbsorbPointer(
      absorbing: _introBlocksPlay,
      child: Stack(
      children: [
        Column(
      children: [
        GameTableHeader(
          game: game,
          onBack: () => _confirmLeave(inGame: true),
          onSettings: () => SettingsSheet.show(context),
          onPlayersList: _openPlayersSheet,
          showPlayersList: true,
          title: 'Phòng ${_c.code}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: GameOpponentRow(
            itemCount: opponents.length,
            activeIndex: _c.isFinished
                ? 0
                : opponents.indexWhere(
                    (p) => p.id == game.currentPlayer.id,
                  ).clamp(0, opponents.isEmpty ? 0 : opponents.length - 1),
            density: density,
            itemBuilder: (context, i) {
              final p = opponents[i];
              final profile = profiles[p.id];
              final virtualCount = _intro.virtualHandCounts[p.id];
              return GameOpponentChip(
                player: p,
                isTurn: !_introBlocksPlay &&
                    !_c.isFinished &&
                    game.currentPlayer.id == p.id,
                isBot: false,
                density: density,
                photoUrl: profile?.photoUrl,
                equippedTitleId: profile?.equippedTitleId,
                cardCountOverride: virtualCount,
                avatarFlyKey: _opponentKeys[p.id],
                catchableUno: catchableId == p.id,
                onCatchUno: catchableId == p.id
                    ? () => _catchUno(p.id)
                    : null,
              );
            },
          ),
        ),
        Expanded(
          child: Center(
            child: GameCenterPiles(
              topCard: game.topCard,
              activeColor: game.activeColor,
              canDraw: myTurn &&
                  (game.mustRespondToDrawStack || !game.drawnThisTurn),
              onDraw: _drawAnimated,
              drawPileCount: game.drawPile.length,
              discardKey: _discardKey,
              drawKey: _drawKey,
              drawFlyKey: _drawFlyKey,
              discardCount: game.discardPile.length,
              hideDiscard: _introBlocksPlay,
            ),
          ),
        ),
        GameStatusBar(
          isMyTurn: myTurn,
          turnLabel: statusLabel,
          canPass: _c.canPass && !_introBlocksPlay,
          onPass: _c.passTurn,
          showUnoButton: showUno,
          onUno: () => unawaited(_callUno()),
          showCatchUnoButton: showCatch,
          catchUnoLabel: catchablePlayer == null
              ? 'Bắt UNO'
              : 'Bắt ${catchablePlayer.name}',
          onCatchUno: catchableId == null
              ? null
              : () => unawaited(_catchUno(catchableId)),
          drawStackCount: myTurn ? game.pendingDrawCount : 0,
          turnSecondsRemaining:
              !_introBlocksPlay && _c.isPlaying ? turnSecs : null,
        ),
        const SizedBox(height: 6),
        _myHand(me),
      ],
        ),
        GameMatchIntroOverlay(
          label: _intro.countdownLabel,
          visible: _intro.phase == GameMatchIntroPhase.countdown,
        ),
      ],
      ),
    );
  }

  Widget _myHand(UnoPlayer me) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _myHandBody(me),
    );
  }

  Widget _myHandBody(UnoPlayer me) {
    if (_intro.blocksInteraction) {
      final virtualCount = _intro.virtualHandCounts[_c.uid] ?? 0;
      return _introHandStrip(virtualCount);
    }

    final myTurn = _c.isMyTurn && !_introBlocksPlay;
    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: me.hand.length,
    );
    final handFp = _intro.activeFingerprint ??
        (_c.game != null
            ? GameMatchIntroController.fingerprint(_c.game!)
            : 'hand');

    return SizedBox(
      key: _handKey,
      height: layout.totalHeight(me.hand.length),
      width: double.infinity,
      child: GamePlayerHandStrip(
        key: ValueKey('hand-$handFp-${me.hand.length}'),
        resetToken: _handResetToken,
        cards: me.hand,
        isMyTurn: myTurn,
        showHints: _showHints,
        canPlay: _c.canPlay,
        selectedIndex: _selectedHandIndex,
        onCardTap: (card, index, globalCenter) =>
            _onCardTap(card, index, globalCenter),
      ),
    );
  }

  Widget _introHandStrip(int cardCount) {
    return GameIntroHandStrip(
      handKey: _introHandKey,
      cardCount: cardCount,
      viewportWidth: MediaQuery.sizeOf(context).width,
    );
  }

  Future<void> _onCardTap(
    UnoCard card,
    int handIndex,
    Offset globalCenter,
  ) async {
    if (_introBlocksPlay) return;
    if (_selectedHandIndex == handIndex) {
      await _playSelectedCard(handIndex, fromGlobal: globalCenter);
      return;
    }
    if (!_c.canPlay(card)) {
      AppSnack.warning(
        context,
        'Không thể chọn lá này / chưa tới lượt',
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    setState(() => _selectedHandIndex = handIndex);
  }

  Future<void> _playSelectedCard(
    int handIndex, {
    Offset? fromGlobal,
  }) async {
    final me = _c.me;
    if (me == null ||
        handIndex < 0 ||
        handIndex >= me.hand.length) {
      AppSnack.warning(
        context,
        'Chọn lá bài trước',
        duration: const Duration(milliseconds: 900),
      );
      return;
    }
    final card = me.hand[handIndex];
    if (!_c.canPlay(card)) {
      setState(() => _selectedHandIndex = null);
      return;
    }
    CardColor? chosen;
    if (card.isWild) {
      chosen = await GamePremiumDialog.pickColor(context);
      if (chosen == null) return;
    }
    await _playCardAnimated(
      card,
      chosenColor: chosen,
      handIndex: handIndex,
      fromGlobal: fromGlobal,
    );
    if (mounted) setState(() => _selectedHandIndex = null);
  }

  Future<void> _handleKicked() async {
    if (!mounted) return;
    _timeoutWatcher.stop();
    _eventFeedback.reset();
    _c.removeListener(_onChange);
    await WaitingRoomSession.instance.ejectLocal();
    if (!mounted) return;
    await GamePremiumDialog.showKicked(
      context,
      onLeave: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  void _showWinDialog() {
    if (!mounted) return;
    final game = _c.game;
    if (game == null || game.winnerId == null) return;
    final winner = game.players.firstWhere((p) => p.id == game.winnerId);
    final iWon = winner.id == _c.uid;
    if (iWon) {
      TitleStore.instance.recordOnlineWin();
      DailyQuestStore.instance.markOnlineWin();
    }
    final room = _c.room;
    final canReplay = _c.isHost &&
        room != null &&
        room.players.length >= GameLimits.minPlayers;
    GamePremiumDialog.showWin(
      context: context,
      youWon: iWon,
      winnerName: winner.name,
      leaveLabel: 'Về sảnh',
      onLeave: () => Navigator.of(context).pop(),
      winSubtitle: iWon
          ? (game.wonByForfeit
              ? 'Đối thủ đã rời — bạn thắng!'
              : 'Chúc mừng, bạn đã hết bài!')
          : null,
      replayLabel: canReplay ? 'Chơi lại' : null,
      onReplay: canReplay
          ? () {
              _eventFeedback.reset();
              _handCounts.clear();
              _intro.reset();
              _resetHandUiState();
              _playQuestRecorded = false;
              _winShown = false;
              _lastRoomStatus = RoomStatus.finished;
              _c.startGame();
            }
          : null,
    );
  }
}
