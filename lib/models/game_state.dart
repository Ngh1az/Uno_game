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

  /// Nhật ký các sự kiện (tiếng Việt) để hiển thị lên UI.
  final List<String> log;

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
    List<String>? log,
    Random? random,
  }) : log = log ?? <String>[],
       _random = random ?? Random();

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
  bool canPlay(UnoCard card) => card.canPlayOn(topCard, activeColor);

  /// Các lá trong tay [player] có thể đánh được.
  List<UnoCard> playableCards(UnoPlayer player) =>
      player.hand.where(canPlay).toList();

  /// Đánh một lá bài.
  /// [chosenColor] bắt buộc khi đánh lá Wild / Wild +4.
  void playCard(String playerId, UnoCard card, {CardColor? chosenColor}) {
    _ensurePlaying();
    _ensureTurn(playerId);

    final player = currentPlayer;
    final index = player.hand.indexOf(card);
    if (index < 0) {
      throw InvalidMoveException('${player.name} không có lá ${card.label}');
    }
    if (!canPlay(card)) {
      throw InvalidMoveException(
        'Không thể đánh ${card.label} lên ${topCard.label} '
        '(màu hiệu lực: ${activeColor.name})',
      );
    }
    if (card.isWild) {
      if (chosenColor == null || chosenColor == CardColor.wild) {
        throw InvalidMoveException('Phải chọn màu khi đánh lá ${card.label}');
      }
    }

    // Bỏ lá khỏi tay, đẩy lên đống đã đánh.
    player.hand.removeAt(index);
    discardPile.add(card);
    activeColor = card.isWild ? chosenColor! : card.color;
    drawnThisTurn = false;

    final colorNote = card.isWild ? ' (chọn ${chosenColor!.name})' : '';
    log.add('${player.name} đánh ${card.label}$colorNote.');

    // Kiểm tra thắng.
    if (player.hasWon) {
      status = GameStatus.finished;
      winnerId = player.id;
      log.add('🎉 ${player.name} đã hết bài và THẮNG!');
      return;
    }
    if (player.hasUno) {
      log.add('${player.name} hô UNO!');
    }

    _applyEffectAndAdvance(card);
  }

  /// Rút 1 lá từ chồng bài. Trả về lá vừa rút.
  /// Nếu lá rút không đánh được, lượt tự chuyển sang người kế tiếp.
  UnoCard drawCard(String playerId) {
    _ensurePlaying();
    _ensureTurn(playerId);
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
        final target = players[_peek(1)];
        final drawn = _drawCards(2);
        target.hand.addAll(drawn);
        log.add('${target.name} bốc 2 lá và mất lượt.');
        _advance(2);
        break;
      case CardType.wildDrawFour:
        final target = players[_peek(1)];
        final drawn = _drawCards(4);
        target.hand.addAll(drawn);
        log.add('${target.name} bốc 4 lá và mất lượt.');
        _advance(2);
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
    'log': log,
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
    log: (json['log'] as List?)?.map((e) => e as String).toList(),
  );
}
