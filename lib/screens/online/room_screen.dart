import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_settings.dart';
import '../../daily_quests/daily_quest_store.dart';
import '../../friends/friends_service.dart';
import '../../models/game_state.dart';
import '../../models/uno_card.dart';
import '../../models/uno_player.dart';
import '../../online/online_game_controller.dart';
import '../../online/auth_service.dart';
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
import '../../widgets/google_account_gate.dart';
import '../../widgets/invite_friends_sheet.dart';
import '../../widgets/lobby_friend_button.dart';
import '../../widgets/game/opponent_chip_density.dart';
import '../../widgets/settings_sheet.dart';
import '../../online/room.dart';
import '../../titles/title_definition.dart';
import '../../widgets/title_name_text.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/game/title_mini_badge.dart';
import '../../widgets/uno_circle_button.dart';

/// Màn hình phòng online: sảnh chờ + bàn chơi premium đỏ–vàng.
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
  final _handKey = GlobalKey();
  final _flyAnchorKey = GlobalKey();
  final _motionKey = GlobalKey<GameCardMotionLayerState>();
  final _handCounts = <String, int>{};
  final _intro = GameMatchIntroController();
  final _opponentKeys = <String, GlobalKey>{};
  bool _winShown = false;
  bool _suppressPlayAnim = false;
  bool _suppressDrawAnim = false;
  bool _introSeqRunning = false;
  UnoCard? _animatingCard;
  int? _flyingHandIndex;
  List<UnoCard>? _frozenHand;
  String? _lastError;
  RoomStatus? _lastRoomStatus;
  int? _introBaselineLogLength;
  String? _introBaselineTopCard;

  @override
  void initState() {
    super.initState();
    _c = WaitingRoomSession.instance.bind(widget.code);
    WaitingRoomSession.instance.setRoomScreenVisible(true);
    _c.addListener(_onChange);
    _intro.addListener(_onIntroChange);
    _eventFeedback.reset();
    _lastRoomStatus = _c.room?.status;
    if (_c.isPlaying && _c.game != null) {
      _intro.markCompleted(GameMatchIntroController.fingerprint(_c.game!));
      _snapshotHands(_c.game!);
    }
    if (!AuthService().isGuest) {
      unawaited(FriendsService().warmFriendsCache());
    }
  }

  void _onIntroChange() {
    if (mounted) setState(() {});
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

    if (game != null && _c.isPlaying) {
      if (_intro.blocksInteraction) {
        _checkIntroFastForward(game);
      }
      if (_intro.isDone) {
        _eventFeedback.onLogChanged(context, game.log);
        _detectOpponentMotion(game);
      }
    } else if (game != null) {
      _eventFeedback.onLogChanged(context, game.log);
    }

    if (status == RoomStatus.playing && game != null) {
      final shouldTrigger = _lastRoomStatus == RoomStatus.waiting ||
          _lastRoomStatus == RoomStatus.finished;
      if (shouldTrigger) {
        unawaited(_maybeStartIntro(game));
      }
    }
    _lastRoomStatus = status ?? _lastRoomStatus;

    if (_c.isFinished && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWinDialog();
      });
    }
    if (_c.isPlaying) _winShown = false;
    setState(() {});
  }

  void _checkIntroFastForward(GameState game) {
    final baseLog = _introBaselineLogLength;
    if (baseLog != null && game.log.length > baseLog) {
      _intro.fastForward();
      return;
    }
    final baseTop = _introBaselineTopCard;
    if (baseTop != null && game.topCard.label != baseTop) {
      _intro.fastForward();
    }
  }

  Future<void> _maybeStartIntro(GameState game) async {
    final fp = GameMatchIntroController.fingerprint(game);
    if (_intro.hasCompleted(fp) || _intro.isActive || _introSeqRunning) return;

    if (WaitingRoomSession.instance.gameStartedWhileMinimized) {
      WaitingRoomSession.instance.clearGameStartedFlag();
      _intro.markCompleted(fp);
      _snapshotHands(game);
      return;
    }

    await _startMatchIntro(game, fp);
  }

  Future<void> _startMatchIntro(GameState game, String fp) async {
    if (_introSeqRunning) return;
    _introSeqRunning = true;

    _intro.begin(fp, game.players.map((p) => p.id).toList());
    _introBaselineLogLength = game.log.length;
    _introBaselineTopCard = game.topCard.label;
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
          handKey: _handKey,
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
    _c.removeListener(_onChange);
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

  void _detectOpponentMotion(GameState state) {
    if (_intro.blocksInteraction) return;

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

    await WidgetsBinding.instance.endOfFrame;
    final from = GameCardMotionLayerState.centerOf(_drawKey);
    final to = GameCardMotionLayerState.centerOf(
      _handKey,
      fallback: Offset(
        MediaQuery.sizeOf(context).width / 2,
        MediaQuery.sizeOf(context).height - 120,
      ),
    );

    _suppressDrawAnim = true;
    await motion.fly(
      card: game.topCard,
      from: from,
      to: to,
      width: GameTheme.pileWidthFor(MediaQuery.sizeOf(context).width),
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
  }) async {
    final game = _c.game;
    if (game == null) return;

    final me = game.players.firstWhere((p) => p.id == _c.uid);
    if (handIndex < 0 || handIndex >= me.hand.length) return;

    _frozenHand = List<UnoCard>.from(me.hand);
    final flying = _frozenHand![handIndex];
    _flyingHandIndex = handIndex;

    final layout = GameHandLayout.compute(
      viewportWidth: MediaQuery.sizeOf(context).width,
      cardCount: _frozenHand!.length,
    );
    final motion = _useCardMotion ? _motion : null;

    try {
      if (motion != null) {
        setState(() => _animatingCard = flying);
        await WidgetsBinding.instance.endOfFrame;

        final from = GameCardMotionLayerState.centerOf(_flyAnchorKey);
        final to = GameCardMotionLayerState.centerOf(_discardKey);
        _suppressPlayAnim = true;
        await motion.fly(
          card: flying,
          from: from,
          to: to,
          width: layout.cardWidth,
        );
        if (!mounted) return;
      } else {
        _suppressPlayAnim = true;
      }

      final declaredUno = game.hasDeclaredUno(_c.uid) ||
          (AppSettings.instance.autoUnoCall && me.hand.length == 2);
      if (AppSettings.instance.autoUnoCall &&
          me.hand.length == 2 &&
          !game.hasDeclaredUno(_c.uid)) {
        await _c.callUno();
      }

      await _c.playCard(
        flying,
        chosenColor: chosenColor,
        handIndex: handIndex,
        declaredUno: declaredUno,
      );
    } finally {
      if (mounted) {
        setState(() {
          _animatingCard = null;
          _flyingHandIndex = null;
          _frozenHand = null;
        });
      }
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
    await WaitingRoomSession.instance.leave();
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

  Future<void> _openInviteFriends() async {
    if (!await requireGoogleAccount(context)) return;
    if (!mounted) return;
    await InviteFriendsSheet.show(context, roomCode: widget.code);
  }

  Widget _waitingView() {
    final room = _c.room!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: UnoCircleButton(
                    icon: Icons.arrow_back,
                    label: '',
                    showLabel: false,
                    size: 38,
                    iconScale: 0.48,
                    onTap: () => _confirmLeave(inGame: false),
                  ),
                ),
                const TitleNamePlain(
                  name: 'Phòng chờ',
                  tier: TitleTier.elite,
                  accent: GameTheme.gold,
                  fontSize: 22,
                  shimmer: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: UnoCircleButton(
                    icon: Icons.home_rounded,
                    label: '',
                    showLabel: false,
                    size: 38,
                    iconScale: 0.48,
                    onTap: _minimizeToHome,
                  ),
                ),
              ],
            ),
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
                border: Border.all(color: GameTheme.gold.withValues(alpha: 0.5)),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: GameTheme.gold,
                side: BorderSide(color: GameTheme.gold.withValues(alpha: 0.45)),
              ),
              onPressed: _openInviteFriends,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Mời bạn bè',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Người chơi (${room.players.length}/${room.maxPlayers})',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final p in room.players)
                  _lobbyPlayerTile(p, room),
              ],
            ),
          ),
          if (_c.isHost)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: GameTheme.gold,
                ),
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
              'Đang chờ bắt đầu...',
              style: TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _lobbyPlayerTile(RoomPlayer player, Room room) {
    final isHost = player.id == room.hostId;

    return Card(
      color: isHost ? const Color(0xCC2A1208) : const Color(0xAA1A0505),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: GameTheme.gold.withValues(alpha: isHost ? 0.62 : 0.25),
          width: isHost ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        leading: _lobbyPlayerAvatar(player, isHost: isHost),
        title: Text(
          player.name,
          style: TextStyle(
            color: isHost ? GameTheme.gold : Colors.white,
            fontWeight: isHost ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        trailing: _lobbyPlayerTrailing(player, room),
      ),
    );
  }

  Widget _lobbyPlayerTrailing(RoomPlayer player, Room room) {
    if (player.id == _c.uid) return const SizedBox.shrink();

    return LobbyFriendButton(targetUid: player.id, targetName: player.name);
  }

  Widget _lobbyPlayerAvatar(RoomPlayer player, {required bool isHost}) {
    final title = player.equippedTitleId == null
        ? null
        : titleById(player.equippedTitleId!);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isHost ? 3 : 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: GameTheme.gold.withValues(alpha: isHost ? 0.95 : 0.45),
                width: isHost ? 2.2 : 1.5,
              ),
              boxShadow: isHost
                  ? [
                      BoxShadow(
                        color: GameTheme.gold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: UserAvatar(
              photoUrl: player.photoUrl,
              displayName: player.name,
              radius: 20,
            ),
          ),
          if (title != null) TitleCornerBadge(title: title),
        ],
      ),
    );
  }

  Widget _tableView() {
    final game = _c.game!;
    final room = _c.room!;
    final meId = _c.uid;
    final opponents = game.players.where((p) => p.id != meId).toList();
    final profiles = {for (final p in room.players) p.id: p};
    final density = OpponentChipDensityX.forOpponentCount(opponents.length);
    final me = game.players.firstWhere(
      (p) => p.id == meId,
      orElse: () => game.players.first,
    );
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
    final statusLabel = _intro.phase == GameMatchIntroPhase.dealing
        ? 'Đang chia bài...'
        : _intro.phase == GameMatchIntroPhase.countdown
            ? 'Chuẩn bị...'
            : myTurn
                ? 'Lượt của bạn'
                : 'Lượt ${game.currentPlayer.name}';

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
          title: 'Phòng ${_c.code}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: GameOpponentRow(
            itemCount: opponents.length,
            activeIndex: opponents.indexWhere(
              (p) => p.id == game.currentPlayer.id,
            ).clamp(0, opponents.isEmpty ? 0 : opponents.length - 1),
            density: density,
            itemBuilder: (context, i) {
              final p = opponents[i];
              final profile = profiles[p.id];
              final virtualCount = _intro.virtualHandCounts[p.id];
              return GameOpponentChip(
                player: p,
                isTurn: !_introBlocksPlay && game.currentPlayer.id == p.id,
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

    final hand = _frozenHand ?? me.hand;
    final myTurn = _c.isMyTurn && !_introBlocksPlay;

    return GamePlayerHandStrip(
      key: _handKey,
      cards: hand,
      isMyTurn: myTurn,
      showHints: _showHints,
      canPlay: _c.canPlay,
      flyingHandIndex: _flyingHandIndex,
      flyAnchorKey: _flyAnchorKey,
      onCardTap: (card, index) => _onCardTap(card, index),
    );
  }

  Widget _introHandStrip(int cardCount) {
    return GameIntroHandStrip(
      handKey: _handKey,
      cardCount: cardCount,
      viewportWidth: MediaQuery.sizeOf(context).width,
    );
  }

  Future<void> _onCardTap(UnoCard card, int handIndex) async {
    if (_introBlocksPlay) return;
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
      chosen = await GamePremiumDialog.pickColor(context);
      if (chosen == null) return;
    }
    await _playCardAnimated(card, chosenColor: chosen, handIndex: handIndex);
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
    GamePremiumDialog.showWin(
      context: context,
      youWon: iWon,
      winnerName: winner.name,
      leaveLabel: 'Về sảnh',
      onLeave: () => Navigator.of(context).pop(),
      replayLabel: _c.isHost ? 'Chơi lại' : null,
      onReplay: _c.isHost
          ? () {
              _eventFeedback.reset();
              _handCounts.clear();
              _intro.reset();
              _lastRoomStatus = RoomStatus.finished;
              _c.startGame();
            }
          : null,
    );
  }
}
