import 'uno_card.dart';

/// Một người chơi trong ván UNO (người thật hoặc bot).
class UnoPlayer {
  final String id;
  final String name;
  final bool isBot;

  /// Bài trên tay. Mutable để engine thêm/bớt khi chơi.
  final List<UnoCard> hand;

  UnoPlayer({
    required this.id,
    required this.name,
    this.isBot = false,
    List<UnoCard>? hand,
  }) : hand = hand ?? <UnoCard>[];

  /// Còn đúng 1 lá -> phải hô "UNO".
  bool get hasUno => hand.length == 1;

  /// Đã hết bài -> thắng.
  bool get hasWon => hand.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isBot': isBot,
    'hand': hand.map((c) => c.toJson()).toList(),
  };

  factory UnoPlayer.fromJson(Map<String, dynamic> json) => UnoPlayer(
    id: json['id'] as String,
    name: json['name'] as String,
    isBot: (json['isBot'] as bool?) ?? false,
    hand: (json['hand'] as List)
        .map((e) => UnoCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  @override
  String toString() => 'UnoPlayer($name, ${hand.length} lá)';
}
