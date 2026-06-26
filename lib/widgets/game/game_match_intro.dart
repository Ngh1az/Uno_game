import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/game_state.dart';
import '../../models/uno_card.dart';
import 'game_card_motion.dart';
import '../uno_card_widget.dart';
import 'game_hand_layout.dart';
import 'game_theme.dart';

enum GameMatchIntroPhase { idle, countdown, dealing, done }

/// Quản lý phase intro mở ván (đếm ngược + chia bài).
class GameMatchIntroController extends ChangeNotifier {
  GameMatchIntroPhase phase = GameMatchIntroPhase.idle;
  String? activeFingerprint;
  String countdownLabel = '3';
  final Map<String, int> virtualHandCounts = {};

  bool get isActive =>
      phase == GameMatchIntroPhase.countdown ||
      phase == GameMatchIntroPhase.dealing;

  bool get isDone =>
      phase == GameMatchIntroPhase.done || phase == GameMatchIntroPhase.idle;

  bool get blocksInteraction => isActive;

  final Set<String> _completedFingerprints = {};

  static String fingerprint(GameState game) {
    final ids = game.players.map((p) => p.id).join('|');
    return '$ids|${game.topCard.label}|${game.discardPile.length}';
  }

  bool hasCompleted(String fp) => _completedFingerprints.contains(fp);

  void markCompleted(String fp) {
    _completedFingerprints.add(fp);
    activeFingerprint = fp;
    phase = GameMatchIntroPhase.done;
    virtualHandCounts.clear();
    notifyListeners();
  }

  void reset() {
    phase = GameMatchIntroPhase.idle;
    activeFingerprint = null;
    countdownLabel = '3';
    virtualHandCounts.clear();
    notifyListeners();
  }

  void begin(String fp, List<String> playerIds) {
    activeFingerprint = fp;
    phase = GameMatchIntroPhase.countdown;
    countdownLabel = '3';
    virtualHandCounts
      ..clear()
      ..addEntries(playerIds.map((id) => MapEntry(id, 0)));
    notifyListeners();
  }

  void initVirtualCounts(List<String> playerIds) {
    virtualHandCounts
      ..clear()
      ..addEntries(playerIds.map((id) => MapEntry(id, 0)));
    notifyListeners();
  }

  void incrementVirtualCount(String playerId) {
    virtualHandCounts[playerId] = (virtualHandCounts[playerId] ?? 0) + 1;
    notifyListeners();
  }

  void setVirtualCount(String playerId, int count) {
    virtualHandCounts[playerId] = count;
    notifyListeners();
  }

  void setAllVirtualCounts(int count) {
    for (final id in virtualHandCounts.keys.toList()) {
      virtualHandCounts[id] = count;
    }
    notifyListeners();
  }

  void setOpponentCounts(int count, String myUid) {
    for (final id in virtualHandCounts.keys) {
      if (id != myUid) virtualHandCounts[id] = count;
    }
    notifyListeners();
  }

  void setCountdownLabel(String label) {
    if (countdownLabel == label) return;
    countdownLabel = label;
    notifyListeners();
  }

  void setDealing() {
    if (phase == GameMatchIntroPhase.dealing) return;
    phase = GameMatchIntroPhase.dealing;
    notifyListeners();
  }

  void markDone() {
    if (activeFingerprint != null) {
      _completedFingerprints.add(activeFingerprint!);
    }
    phase = GameMatchIntroPhase.done;
    virtualHandCounts.clear();
    notifyListeners();
  }

  void fastForward() {
    if (!isActive) return;
    if (activeFingerprint != null) {
      _completedFingerprints.add(activeFingerprint!);
    }
    phase = GameMatchIntroPhase.done;
    virtualHandCounts.clear();
    notifyListeners();
  }
}

/// Overlay đếm ngược 3-2-1 + "BẮT ĐẦU!".
class GameMatchIntroOverlay extends StatelessWidget {
  const GameMatchIntroOverlay({
    super.key,
    required this.label,
    required this.visible,
  });

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        alignment: Alignment.center,
        color: const Color(0x661A0505),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey(label),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xCC1A0505),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GameTheme.gold.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: GameTheme.gold.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: GameTheme.gold,
                fontSize: label.length <= 2 ? 72 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: label.length <= 2 ? 2 : 1.5,
                shadows: [
                  Shadow(
                    color: GameTheme.gold.withValues(alpha: 0.65),
                    blurRadius: 18,
                  ),
                  const Shadow(color: Colors.black87, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chạy đếm ngược rồi (tuỳ chọn) sequence chia bài.
class GameMatchIntroRunner {
  GameMatchIntroRunner._();

  static const _dummyDealCard = UnoCard(
    color: CardColor.blue,
    type: CardType.number,
    number: 0,
  );

  static Future<void> runCountdown(GameMatchIntroController controller) async {
    const steps = ['3', '2', '1', 'BẮT ĐẦU!'];
    for (final step in steps) {
      controller.setCountdownLabel(step);
      final delay = step == 'BẮT ĐẦU!' ? 500 : 850;
      await Future<void>.delayed(Duration(milliseconds: delay));
    }
  }

  static Future<void> runDealSequence({
    required GameCardMotionLayerState? motion,
    required GameMatchIntroController controller,
    required GameState game,
    required String myUid,
    required GlobalKey drawKey,
    required GlobalKey handKey,
    required Map<String, GlobalKey> opponentKeys,
    required double pileWidth,
    required double viewportWidth,
    int handSize = 7,
  }) async {
    final players = game.players;
    controller.initVirtualCounts(players.map((p) => p.id).toList());

    await _waitForLayout(drawKey, handKey);

    final from = await _resolveDrawOrigin(drawKey);

    final handLayout = GameHandLayout.compute(
      viewportWidth: viewportWidth,
      cardCount: handSize,
    );

    // Đối thủ/bot: cập nhật số lá ngay.
    controller.setOpponentCounts(handSize, myUid);

    if (motion == null || from == null) {
      controller.setVirtualCount(myUid, handSize);
      return;
    }

    // Tay mình: bay lần lượt lá 1 → 7, nhanh.
    for (var i = 0; i < handSize; i++) {
      if (controller.isDone) return;

      final to = await _resolveHandSlotCenter(
        handKey: handKey,
        cardIndex: i,
        layout: handLayout,
      );

      if (to != null) {
        if (i == 0) unawaited(HapticFeedback.lightImpact());
        await motion.fly(
          card: _dummyDealCard,
          from: from,
          to: to,
          width: pileWidth,
          faceDown: true,
          duration: const Duration(milliseconds: 200),
        );
        if (controller.isDone) return;
      }

      controller.setVirtualCount(myUid, i + 1);

      if (i < handSize - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 55));
      }
    }

    controller.setVirtualCount(myUid, handSize);
    controller.setOpponentCounts(handSize, myUid);
  }

  /// Lật lá khởi đầu từ chồng úp sang vị trí đống đánh (luật UNO).
  static Future<void> runStarterReveal({
    required GameCardMotionLayerState? motion,
    required UnoCard starterCard,
    required GlobalKey drawKey,
    required double pileWidth,
    Duration pauseBeforeReveal = const Duration(milliseconds: 280),
  }) async {
    if (motion == null) return;

    await Future<void>.delayed(pauseBeforeReveal);

    final from = await _resolveDrawOrigin(drawKey);
    if (from == null) return;

    // Vị trí đống đánh bên trái chồng rút (khớp layout 2 chồng).
    final to = from - Offset(pileWidth * 1.55, 0);

    await motion.fly(
      card: starterCard,
      from: from,
      to: to,
      width: pileWidth,
      duration: const Duration(milliseconds: 380),
    );
  }

  static Future<void> _waitForLayout(
    GlobalKey drawKey,
    GlobalKey handKey,
  ) async {
    for (var i = 0; i < 12; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (_hasLayout(drawKey) && _hasLayout(handKey)) return;
    }
  }

  static bool _hasLayout(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    return box != null && box.hasSize;
  }

  static Future<Offset?> _resolveDrawOrigin(GlobalKey drawKey) async {
    for (var i = 0; i < 12; i++) {
      final center = GameCardMotionLayerState.centerOf(drawKey);
      if (center != Offset.zero) return center;
      await WidgetsBinding.instance.endOfFrame;
    }
    return null;
  }

  static Future<Offset?> _resolveHandSlotCenter({
    required GlobalKey handKey,
    required int cardIndex,
    required GameHandLayout layout,
  }) async {
    for (var i = 0; i < 12; i++) {
      final center = _handCardGlobalCenter(
        handKey: handKey,
        cardIndex: cardIndex,
        layout: layout,
      );
      if (center != null) return center;
      await WidgetsBinding.instance.endOfFrame;
    }
    return null;
  }

  static Offset? _handCardGlobalCenter({
    required GlobalKey handKey,
    required int cardIndex,
    required GameHandLayout layout,
  }) {
    final ctx = handKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final local = layout.slotLocalCenter(cardIndex, introStrip: true);
    return box.localToGlobal(local);
  }
}

/// Tay bài úp trong lúc intro chia bài.
class GameIntroHandStrip extends StatelessWidget {
  const GameIntroHandStrip({
    super.key,
    required this.handKey,
    required this.cardCount,
    required this.viewportWidth,
  });

  final GlobalKey handKey;
  final int cardCount;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    const handSize = 7;
    final layout = GameHandLayout.compute(
      viewportWidth: viewportWidth,
      cardCount: handSize,
    );

    return Container(
      key: handKey,
      height: layout.stripHeight + 20,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xAA1A0505),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: GameTheme.gold.withValues(alpha: 0.3))),
      ),
      child: cardCount == 0
          ? const SizedBox.shrink()
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: GameHandLayout.horizontalPadding,
                vertical: GameHandLayout.introVerticalPadding,
              ),
              itemCount: cardCount,
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(
                  right: i < cardCount - 1 ? layout.gap : 0,
                ),
                child: UnoCardBack(width: layout.cardWidth),
              ),
            ),
    );
  }
}
