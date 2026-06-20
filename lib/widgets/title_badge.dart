import 'package:flutter/material.dart';

import '../titles/title_definition.dart';

/// Badge nhỏ hiển thị danh hiệu đang đeo.
class TitleBadge extends StatelessWidget {
  const TitleBadge({
    super.key,
    required this.title,
    this.compact = false,
    this.onTap,
  });

  final TitleDefinition title;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = Color.lerp(title.color, Colors.white, 0.35)!;
    final fontSize = compact ? 10.5 : 11.5;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC1A0505),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: title.color.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: title.color.withValues(alpha: 0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(title.icon, color: iconColor, size: compact ? 13 : 14),
          SizedBox(width: compact ? 4 : 5),
          Flexible(
            child: Text(
              title.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: title.color.withValues(alpha: 0.85), blurRadius: 8),
                  const Shadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(onTap: onTap, child: content);
  }
}
