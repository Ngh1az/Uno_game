import 'dart:math';

import 'uno_card.dart';
import 'uno_deck.dart';
import 'uno_player.dart';

/// Trạng thái ván chơi.
enum GameStatus { playing, finished }

/// Chiều đi của lượt chơi.
enum PlayDirection { clockwise, counterClockwise }

/// Lỗi khi thực hiện nước đi không hợp lệ.
class InvalidMoveException implements Exception {
  final String message;
  InvalidMoveException(this.message);
  @override
  String toString() => 'InvalidMoveException: $message';
}

/// Engine luật chơi UNO (chạy offline, thuần logic, dễ test và serialize).
///
/// House rule: +2/+4 có thể cộng dồn — dùng [pendingDrawCount], [acceptDrawStack].
///
/// Quy ước lượt chơi:
/// - Đến lượt: người chơi gọi [playCard] HOẶC [drawCard].
/// - [drawCard] rút đúng 1 lá. Nếu lá rút được có thể đánh, lượt vẫn ở người đó
///   để họ chọn [playCard] lá đó hoặc [endTurn]. Nếu không đánh được, lượt tự
///   chuyển sang người kế tiếp.
class GameState {
  final List<UnoPlayer> players;
  final List<UnoCard> drawPile;
  final List<UnoCard> discardPile;

  int currentPlayerIndex;
  PlayDirection direction;

  /// Màu đang có hiệu lực (quan trọng khi lá trên cùng là Wild đã chọn màu).
  CardColor activeColor;

  GameStatus status;
  String? winnerId;

  /// Đã rút bài trong lượt hiện tại hay chưa (mỗi lượt chỉ được rút 1 lần).
  bool drawnThisTurn;

  /// Số lá phải rút do chuỗi +2/+4 (luật cộng dồn — house rule).
  int pendingDrawCount;

  /// Người chơi đã hô UNO (khi còn 2 lá trước khi đánh, hoặc khi vừa xuống còn 1 lá).
  final Set<String> unoDeclaredBeforePlay;

  /// Người chơi còn 1 lá nhưng quên hô UNO — đối thủ có thể bắt lỗi.
  String? catchableUnoPlayerId;

  /// Nhật ký các sự kiện (tiếng Việt) để hiển thị lên UI.
  final List<String> log;

  /// Số lần hết giờ liên tiếp (online) — đủ [TurnTimeoutPolicy.maxStrikes] thì coi như rời ván.
  final Map<String, int> timeoutStrikes;

  final Random _random;

  GameState({
    required this.players,
    required this.drawPile,
    required this.discardPile,
    required this.currentPlayerIndex,
    required this.direction,
    required this.activeColor,
    required this.status,
    this.winnerId,
    this.drawnThisTurn = false,
    this.pendingDrawCount = 0,
    Set<String>? unoDeclaredBeforePlay,
    this.catchableUnoPlayerId,
    List<String>? log,
    Map<String, int>? timeoutStrikes,
    Random? random,
  }) : unoDeclaredBeforePlay = unoDeclaredBeforePlay ?? <String>{},
       log = log ?? <String>[],
       timeoutStrikes = timeoutStrikes ?? <String, int>{},
       _random = random ?? Random();

  bool hasDeclaredUno(String playerId) => unoDeclaredBeforePlay.contains(playerId);

  int timeoutStrikeCount(String playerId) => timeoutStrikes[playerId] ?? 0;

  void resetTimeoutStrike(String playerId) => timeoutStrikes.remove(playerId);

  void incrementTimeoutStrike(String playerId) {
    timeoutStrikes[playerId] = timeoutStrikeCount(playerId) + 1;
  }

  bool get mustRespondToDrawStack => pendingDrawCount > 0;

  /// Lá trên cùng của đống bài đã đánh.
  UnoCard get topCard => discardPile.last;

  /// Người chơi đang tới lượt.
  UnoPlayer get currentPlayer => players[currentPlayerIndex];

  /// Tạo ván mới: xáo bài, chia [handSize] lá mỗi người, lật lá đầu tiên.
  /// Lá khởi đầu luôn là lá số thường để tránh hiệu ứng phức tạp ngay đầu ván.
  factory GameState.newGame({
    required List<UnoPlayer> players,
    int handSize = 7,
    Random? random,
  }) {
    if (players.length < 2) {
      throw ArgumentError('Cần ít nhất 2 người chơi');
    }
    final rng = random ?? Random();
    final deck = UnoDeck.buildShuffledDeck(random: rng);

    // Làm sạch tay bài rồi chia bài.
    for (final p in players) {
      p.hand.clear();
    }
    for (var i = 0; i < handSize; i++) {
      for (final p in players) {
        p.hand.add(deck.removeLast());
      }
    }

    // Tìm lá số thường làm lá khởi đầu (đưa các lá khác xuống cuối bộ).
    var first = deck.removeLast();
    while (first.type != CardType.number) {
      deck.insert(0, first);
      first = deck.removeLast();
    }

    final state = GameState(
      players: players,
      drawPile: deck,
      discardPile: [first],
      currentPlayerIndex: 0,
      direction: PlayDirection.clockwise,
      activeColor: first.color,
      status: GameStatus.playing,
      random: rng,
    );
    state.log.add('Ván mới bắt đầu. Lá khởi đầu: ${first.label}.');
    state.log.add('Tới lượt ${state.currentPlayer.name}.');
    return state;
  }

  /// Tìm người chơi theo id.
  UnoPlayer playerById(String id) =>
      players.firstWhere((p) => p.id == id,
          orElse: () => throw InvalidMoveException('Không có người chơi $id'));

  /// Một lá có đánh được lên lá trên cùng (theo màu đang hiệu lực) hay không.
  bool canPlay(UnoCard card) {
    if (pendingDrawCount > 0) {
      return card.type == CardType.drawTwo ||
          card.type == CardType.wildDrawFour;
    }
    return card.canPlayOn(topCard, activeColor);
  }

  /// Các lá trong tay [player] có thể đánh được.
  List<UnoCard> playableCards(UnoPlayer player) =>
      player.hand.where(canPlay).toList();

  /// Hô "UNO!" khi sắp đánh lá áp chót (còn 2 lá) hoặc ngay sau khi xuống còn 1 lá.
  void callUno(String playerId) {
    _ensurePlaying();
    _ensureTurn(playerId);
    final player = currentPlayer;
    if (player.hand.length != 2 && player.hand.length != 1) {
      throw InvalidMoveException('Chỉ hô UNO khi còn 1–2 lá.');
    }
    if (player.hand.length == 1 && catchableUnoPlayerId == playerId) {
      throw InvalidMoveException('Đã quá muộn — đối thủ có thể bắt lỗi.');
    }
    unoDeclaredBeforePlay.add(playerId);
    log.add('${player.name} hô UNO!');
  }

  /// Bắt lỗi quên hô UNO — đối thủ rút thêm 2 lá.
  void catchUno(String catcherId, String targetId) {
    _ensurePlaying();
    if (catchableUnoPlayerId != targetId) {
      throw InvalidMoveException('Không thể bắt lỗi UNO lúc này.');
    }
    if (catcherId == targetId) {
      throw InvalidMoveException('Không thể tự bắt lỗi UNO của chính mình.');
    }
    final target = playerById(targetId);
    final catcher = playerById(catcherId);
    final drawn = _drawCards(2);
    target.hand.addAll(drawn);
    catchableUnoPlayerId = null;
    log.add('${catcher.name} bắt ${target.name} quên UNO — rút 2 lá.');
  }

  /// Nhận toàn bộ lá tích lũy từ chuỗi +2/+4 rồi mất lượt.
  void acceptDrawStack(String playerId) {
    _ensurePlaying();
    _ensureTurn(playerId);
    _expireUnoCatchWindow(playerId);
    if (pendingDrawCount <= 0) {
      throw InvalidMoveException('Không có chuỗi +2/+4 đang chờ.');
    }

    final player = currentPlayer;
    final count = pendingDrawCount;
    pendingDrawCount = 0;
    drawnThisTurn = false;
    final drawn = _drawCards(count);
    player.hand.addAll(drawn);
    log.add('${player.name} nhận $count lá từ chuỗi +2/+4.');
    _advance(1);
    if (status == GameStatus.playing) {
      log.add('Tới lượt ${currentPlayer.name}.');
    }
  }

  /// Đánh một lá bài.
  /// [declaredUno] true khi người chơi hô UNO cùng lúc đánh lá áp chót (2 → 1 lá).
  /// [autoUno] true khi cài đặt "tự động gọi UNO" — engine tự coi là đã hô khi 2 → 1 lá.
  /// [chosenColor] bắt buộc khi đánh lá Wild / Wild +4.
  /// [handIndex] dùng khi có nhiều lá trùng màu/loại trong tay.
  void playCard(
    String playerId,
    UnoCard card, {
    CardColor? chosenColor,
    int? handIndex,
    bool declaredUno = false,
    bool autoUno = false,
  }) {
    _ensurePlaying();
    _ensureTurn(playerId);
    _expireUnoCatchWindow(playerId);

    final player = currentPlayer;
    final handBefore = player.hand.length;
    final index = _resolveHandIndex(player.hand, card, handIndex: handIndex);
    if (index < 0) {
      throw InvalidMoveException('${player.name} không có lá ${card.label}');
    }
    final handCard = player.hand[index];
    if (pendingDrawCount > 0) {
      if (handCard.type != CardType.drawTwo &&
          handCard.type != CardType.wildDrawFour) {
        throw InvalidMoveException(
          'Phải đánh +2/+4 hoặc nhận $pendingDrawCount lá.',
        );
      }
    } else if (!canPlay(handCard)) {
      throw InvalidMoveException(
        'Không thể đánh ${handCard.label} lên ${topCard.label} '
        '(màu hiệu lực: ${activeColor.name})',
      );
    }
    if (handCard.isWild) {
      if (chosenColor == null || chosenColor == CardColor.wild) {
        throw InvalidMoveException('Phải chọn màu khi đánh lá ${handCard.label}');
      }
    }

    // Bỏ lá khỏi tay, đẩy lên đống đã đánh.
    player.hand.removeAt(index);
    discardPile.add(handCard);
    activeColor = handCard.isWild ? chosenColor! : handCard.color;
    drawnThisTurn = false;

    final colorNote = handCard.isWild ? ' (chọn ${chosenColor!.name})' : '';
    log.add('${player.name} đánh ${handCard.label}$colorNote.');

    if (handBefore == 2 && player.hand.length == 1) {
      final priorDeclared = unoDeclaredBeforePlay.remove(playerId);
      final declared = declaredUno || priorDeclared || autoUno;
      if (!declared) {
        catchableUnoPlayerId = playerId;
        log.add('${player.name} quên hô UNO!');
      } else if (autoUno && !priorDeclared && !declaredUno) {
        log.add('${player.name} hô UNO!');
      }
    }

    // Kiểm tra thắng.
    if (player.hasWon) {
      status = GameStatus.finished;
      winnerId = player.id;
      log.add('🎉 ${player.name} đã hết bài và THẮNG!');
      return;
    }

    _applyEffectAndAdvance(handCard);
  }

  /// Tìm vị trí lá trong tay — ưu tiên cùng instance, rồi index gợi ý.
  static int _resolveHandIndex(
    List<UnoCard> hand,
    UnoCard card, {
    int? handIndex,
  }) {
    if (handIndex != null && handIndex >= 0 && handIndex < hand.length) {
      final at = hand[handIndex];
      if (identical(at, card) || at == card) return handIndex;
    }
    final byIdentity = hand.indexWhere((c) => identical(c, card));
    if (byIdentity >= 0) return byIdentity;

    final matches = <int>[];
    for (var i = 0; i < hand.length; i++) {
      if (hand[i] == card) matches.add(i);
    }
    if (matches.isEmpty) return -1;
    if (matches.length == 1) return matches.first;
    throw InvalidMoveException(
      'Có ${matches.length} lá ${card.label} — hãy chọn đúng lá trong tay.',
    );
  }

  /// Rút 1 lá từ chồng bài. Trả về lá vừa rút.
  /// Nếu lá rút không đánh được, lượt tự chuyển sang người kế tiếp.
  UnoCard drawCard(String playerId) {
    _ensurePlaying();
    _ensureTurn(playerId);
    _expireUnoCatchWindow(playerId);
    if (pendingDrawCount > 0) {
      throw InvalidMoveException(
        'Phải đánh +2/+4 hoặc chạm chồng bài để nhận $pendingDrawCount lá.',
      );
    }
    if (drawnThisTurn) {
      throw InvalidMoveException(
        'Đã rút bài trong lượt này; hãy đánh lá rút được hoặc kết thúc lượt.',
      );
    }

    final player = currentPlayer;
    final drawn = _drawCards(1).first;
    player.hand.add(drawn);
    drawnThisTurn = true;
    log.add('${player.name} rút 1 lá.');
    if (player.hand.length > 2) {
      unoDeclaredBeforePlay.remove(playerId);
    }

    if (!canPlay(drawn)) {
      log.add('${player.name} không có lá đánh được, qua lượt.');
      drawnThisTurn = false;
      _advance(1);
    }
    return drawn;
  }

  /// Kết thúc lượt sau khi đã rút bài mà không muốn đánh.
  void endTurn(String playerId) {
    _ensurePlaying();
    _ensureTurn(playerId);
    _expireUnoCatchWindow(playerId);
    if (pendingDrawCount > 0) {
      throw InvalidMoveException(
        'Phải đánh +2/+4 hoặc nhận $pendingDrawCount lá.',
      );
    }
    if (!drawnThisTurn) {
      throw InvalidMoveException(
        'Phải rút bài trước khi kết thúc lượt nếu không đánh được lá nào.',
      );
    }
    drawnThisTurn = false;
    log.add('${currentPlayer.name} kết thúc lượt.');
    _advance(1);
  }

  // ----- Nội bộ -----

  void _applyEffectAndAdvance(UnoCard card) {
    switch (card.type) {
      case CardType.number:
      case CardType.wild:
        _advance(1);
        break;
      case CardType.skip:
        final skipped = players[_peek(1)].name;
        log.add('$skipped bị mất lượt (Skip).');
        _advance(2);
        break;
      case CardType.reverse:
        direction = direction == PlayDirection.clockwise
            ? PlayDirection.counterClockwise
            : PlayDirection.clockwise;
        log.add('Đảo chiều!');
        // 2 người: Reverse có tác dụng như Skip.
        _advance(players.length == 2 ? 2 : 1);
        break;
      case CardType.drawTwo:
        pendingDrawCount += 2;
        log.add('Chuỗi +2/+4: tổng $pendingDrawCount lá.');
        _advance(1);
        break;
      case CardType.wildDrawFour:
        pendingDrawCount += 4;
        log.add('Chuỗi +2/+4: tổng $pendingDrawCount lá.');
        _advance(1);
        break;
    }
    if (status == GameStatus.playing) {
      log.add('Tới lượt ${currentPlayer.name}.');
    }
  }

  /// Rút [n] lá; tự trộn lại đống đã đánh khi hết bài.
  List<UnoCard> _drawCards(int n) {
    final result = <UnoCard>[];
    for (var i = 0; i < n; i++) {
      if (drawPile.isEmpty) {
        _reshuffleDiscardIntoDraw();
        if (drawPile.isEmpty) break; // hết sạch bài, không thể rút thêm
      }
      result.add(drawPile.removeLast());
    }
    return result;
  }

  /// Lấy đống đã đánh (trừ lá trên cùng) trộn lại làm chồng bài rút.
  void _reshuffleDiscardIntoDraw() {
    if (discardPile.length <= 1) return;
    final top = discardPile.removeLast();
    drawPile.addAll(UnoDeck.shuffled(discardPile, random: _random));
    discardPile
      ..clear()
      ..add(top);
    log.add('Trộn lại đống bài đã đánh.');
  }

  /// Chỉ số người chơi cách [currentPlayerIndex] [steps] bước theo chiều hiện tại.
  int _peek(int steps) {
    final n = players.length;
    final dir = direction == PlayDirection.clockwise ? 1 : -1;
    return ((currentPlayerIndex + dir * steps) % n + n) % n;
  }

  /// Chỉ số người chơi cách [fromIndex] [steps] bước theo chiều hiện tại.
  int _peekFromIndex(int fromIndex, int steps) {
    final n = players.length;
    final dir = direction == PlayDirection.clockwise ? 1 : -1;
    return ((fromIndex + dir * steps) % n + n) % n;
  }

  /// Hết cửa bắt UNO khi người kế tiếp bắt đầu lượt (rút hoặc đánh).
  void _expireUnoCatchWindow(String actingPlayerId) {
    if (catchableUnoPlayerId == null) return;
    final catchableIdx =
        players.indexWhere((p) => p.id == catchableUnoPlayerId);
    if (catchableIdx < 0) {
      catchableUnoPlayerId = null;
      return;
    }
    final nextIdx = _peekFromIndex(catchableIdx, 1);
    if (players[nextIdx].id == actingPlayerId) {
      catchableUnoPlayerId = null;
    }
  }

  void _advance(int steps) {
    currentPlayerIndex = _peek(steps);
  }

  void _ensurePlaying() {
    if (status != GameStatus.playing) {
      throw InvalidMoveException('Ván đã kết thúc.');
    }
  }

  void _ensureTurn(String playerId) {
    if (currentPlayer.id != playerId) {
      throw InvalidMoveException(
        'Chưa tới lượt $playerId (đang tới lượt ${currentPlayer.id}).',
      );
    }
  }

  // ----- Serialize (phục vụ Firebase) -----

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'drawPile': drawPile.map((c) => c.toJson()).toList(),
    'discardPile': discardPile.map((c) => c.toJson()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'direction': direction.name,
    'activeColor': activeColor.name,
    'status': status.name,
    'winnerId': winnerId,
    'drawnThisTurn': drawnThisTurn,
    'pendingDrawCount': pendingDrawCount,
    'unoDeclaredBeforePlay': unoDeclaredBeforePlay.toList(),
    'catchableUnoPlayerId': catchableUnoPlayerId,
    'log': log,
    'timeoutStrikes': timeoutStrikes,
  };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    players: (json['players'] as List)
        .map((e) => UnoPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    drawPile: (json['drawPile'] as List)
        .map((e) => UnoCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    discardPile: (json['discardPile'] as List)
        .map((e) => UnoCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    currentPlayerIndex: json['currentPlayerIndex'] as int,
    direction: PlayDirection.values.byName(json['direction'] as String),
    activeColor: CardColor.values.byName(json['activeColor'] as String),
    status: GameStatus.values.byName(json['status'] as String),
    winnerId: json['winnerId'] as String?,
    drawnThisTurn: (json['drawnThisTurn'] as bool?) ?? false,
    pendingDrawCount: (json['pendingDrawCount'] as int?) ?? 0,
    unoDeclaredBeforePlay: (json['unoDeclaredBeforePlay'] as List?)
        ?.map((e) => e as String)
        .toSet(),
    catchableUnoPlayerId: json['catchableUnoPlayerId'] as String?,
    log: (json['log'] as List?)?.map((e) => e as String).toList(),
    timeoutStrikes: (json['timeoutStrikes'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
  );
}
