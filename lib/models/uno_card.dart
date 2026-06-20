import 'package:flutter/material.dart';

/// Màu của lá bài UNO. `wild` dùng cho lá Đổi màu / +4 (chưa chọn màu).
enum CardColor { red, yellow, green, blue, wild }

/// Loại lá bài.
enum CardType { number, skip, reverse, drawTwo, wild, wildDrawFour }

/// Một lá bài UNO bất biến (immutable).
@immutable
class UnoCard {
  final CardColor color;
  final CardType type;

  /// Giá trị số 0..9, chỉ có với [CardType.number]; còn lại là null.
  final int? number;

  const UnoCard({required this.color, required this.type, this.number})
    : assert(
        type != CardType.number || number != null,
        'Lá số bắt buộc phải có number',
      );

  /// Lá đổi màu (wild / +4) chưa gắn màu cố định.
  bool get isWild =>
      type == CardType.wild || type == CardType.wildDrawFour;

  /// Lá có hiệu ứng đặc biệt (không phải lá số thường).
  bool get isAction => type != CardType.number;

  /// Tên màu dùng cho tên file ảnh: red / yellow / green / blue.
  String get _colorName => color.name;

  /// Đường dẫn ảnh trong assets tương ứng với lá bài.
  String get assetPath {
    const base = 'assets/images/cards';
    switch (type) {
      case CardType.number:
        return '$base/${_colorName}_$number.png';
      case CardType.skip:
        return '$base/${_colorName}_skip.png';
      case CardType.reverse:
        return '$base/${_colorName}_reverse.png';
      case CardType.drawTwo:
        return '$base/${_colorName}_draw2.png';
      case CardType.wild:
        return '$base/wild.png';
      case CardType.wildDrawFour:
        return '$base/wild_draw4.png';
    }
  }

  /// Nhãn ngắn để hiển thị/debug, ví dụ: "Red 5", "Blue Skip", "Wild +4".
  String get label {
    final c = color == CardColor.wild
        ? ''
        : '${color.name[0].toUpperCase()}${color.name.substring(1)} ';
    switch (type) {
      case CardType.number:
        return '$c$number';
      case CardType.skip:
        return '${c}Skip';
      case CardType.reverse:
        return '${c}Reverse';
      case CardType.drawTwo:
        return '$c+2';
      case CardType.wild:
        return 'Wild';
      case CardType.wildDrawFour:
        return 'Wild +4';
    }
  }

  /// Kiểm tra lá [this] có đánh được lên [top] hay không (luật UNO cơ bản).
  /// [activeColor] là màu đang có hiệu lực (quan trọng khi lá trên cùng là Wild
  /// đã được chọn màu).
  bool canPlayOn(UnoCard top, CardColor activeColor) {
    if (isWild) return true; // Wild / +4 luôn đánh được
    if (color == activeColor) return true; // trùng màu
    if (type == top.type) {
      // Trùng loại: cùng là số phải trùng giá trị số
      if (type == CardType.number) return number == top.number;
      return true;
    }
    return false;
  }

  /// Chuyển lá bài thành JSON (phục vụ đồng bộ Firebase sau này).
  Map<String, dynamic> toJson() => {
    'color': color.name,
    'type': type.name,
    'number': number,
  };

  /// Khôi phục lá bài từ JSON.
  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
    color: CardColor.values.byName(json['color'] as String),
    type: CardType.values.byName(json['type'] as String),
    number: json['number'] as int?,
  );

  /// Trả về bản sao với màu đã chọn (dùng cho lá Wild sau khi người chơi chọn màu).
  UnoCard withChosenColor(CardColor chosen) {
    assert(isWild, 'Chỉ lá Wild mới cần chọn màu');
    assert(chosen != CardColor.wild, 'Phải chọn 1 màu cụ thể');
    return UnoCard(color: chosen, type: type, number: number);
  }

  @override
  bool operator ==(Object other) =>
      other is UnoCard &&
      other.color == color &&
      other.type == type &&
      other.number == number;

  @override
  int get hashCode => Object.hash(color, type, number);

  @override
  String toString() => 'UnoCard($label)';
}
