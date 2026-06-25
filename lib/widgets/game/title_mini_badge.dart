import 'package:flutter/material.dart';

import '../../titles/title_definition.dart';

/// Danh hiệu nhỏ trên chip đối thủ: icon tier + tên rút gọn (tuỳ chế độ).
class TitleMiniBadge extends StatelessWidget {
  const TitleMiniBadge({
    super.key,
    required this.title,
    required this.showText,
    this.maxChars = 10,
  });

  final TitleDefinition title;
  final bool showText;
  final int maxChars;

  String get _shortName {
    final name = title.name.trim();
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: showText
          ? Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(title.icon, size: 9, color: title.color),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      _shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: title.color,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: title.color.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Icon danh hiệu góc avatar.
class TitleCornerBadge extends StatelessWidget {
  const TitleCornerBadge({super.key, required this.title});

  final TitleDefinition title;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -2,
      top: -2,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A0505),
          border: Border.all(color: title.color, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: title.color.withValues(alpha: 0.35),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(title.icon, size: 9, color: title.color),
      ),
    );
  }
}
