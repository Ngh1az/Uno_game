import 'package:flutter/material.dart';

import '../titles/title_definition.dart';

/// Màu + khung UI theo cấp danh hiệu.
abstract final class TitleTierTheme {
  static const _gold = Color(0xFFFFD54F);

  static Color sectionAccent(TitleTier tier) {
    switch (tier) {
      case TitleTier.starter:
        return const Color(0xFF81C784);
      case TitleTier.shop:
        return _gold;
      case TitleTier.achievement:
        return const Color(0xFF64B5F6);
      case TitleTier.elite:
        return const Color(0xFFFF7043);
    }
  }

  static IconData sectionIcon(TitleTier tier) {
    switch (tier) {
      case TitleTier.starter:
        return Icons.flag_rounded;
      case TitleTier.shop:
        return Icons.monetization_on_rounded;
      case TitleTier.achievement:
        return Icons.emoji_events_rounded;
      case TitleTier.elite:
        return Icons.whatshot_rounded;
    }
  }

  static String sectionHint(TitleTier tier) {
    switch (tier) {
      case TitleTier.starter:
        return 'Dễ mở — chơi vài ván';
      case TitleTier.shop:
        return 'Mua bằng xu UNO';
      case TitleTier.achievement:
        return 'Hoàn thành thành tích';
      case TitleTier.elite:
        return 'Chỉ thắng online — không bán xu';
    }
  }

  static Widget tierChip(TitleDefinition def) {
    final accent = sectionAccent(def.tier);
    final label = switch (def.tier) {
      TitleTier.starter => 'TẬP SỰ',
      TitleTier.shop => 'MUA XU',
      TitleTier.achievement => 'THÀNH TÍCH',
      TitleTier.elite => 'BOSS ONLINE',
    };
    final icon = switch (def.tier) {
      TitleTier.starter => Icons.eco_rounded,
      TitleTier.shop => Icons.shopping_bag_rounded,
      TitleTier.achievement => Icons.military_tech_rounded,
      TitleTier.elite => Icons.local_fire_department_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCardShell({
    required TitleDefinition def,
    required bool unlocked,
    required bool equipped,
    required Widget child,
  }) {
    final accent = sectionAccent(def.tier);
    const equippedGold = Color(0xFFFFC400);

    switch (def.tier) {
      case TitleTier.starter:
      case TitleTier.achievement:
        return _softTierCardShell(
          def: def,
          unlocked: unlocked,
          equipped: equipped,
          child: child,
        );

      case TitleTier.shop:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: unlocked
                  ? [
                      _gold.withValues(alpha: 0.22),
                      const Color(0xFF3D2800),
                      const Color(0xFF1A0505),
                    ]
                  : [
                      _gold.withValues(alpha: 0.08),
                      const Color(0x882A0707),
                    ],
            ),
            border: Border.all(
              color: equipped
                  ? equippedGold
                  : _gold.withValues(alpha: unlocked ? 0.7 : 0.35),
              width: equipped ? 2 : 1.5,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: child,
        );

      case TitleTier.elite:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: unlocked
                  ? [
                      const Color(0xFFFFF8E1),
                      accent,
                      const Color(0xFFFF6F00),
                    ]
                  : [
                      accent.withValues(alpha: 0.4),
                      accent.withValues(alpha: 0.15),
                    ],
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  def.color.withValues(alpha: unlocked ? 0.3 : 0.12),
                  const Color(0xFF1A0505),
                  const Color(0xFF0D0202),
                ],
              ),
              border: equipped
                  ? Border.all(color: equippedGold, width: 2)
                  : null,
            ),
            child: child,
          ),
        );
    }
  }

  /// Tập sự & Cày cuốc — cùng họ khung với Mua xu, nhưng nhẹ hơn Boss/Mua xu.
  static Widget _softTierCardShell({
    required TitleDefinition def,
    required bool unlocked,
    required bool equipped,
    required Widget child,
  }) {
    const equippedGold = Color(0xFFFFC400);
    const radius = 14.0;
    final tierAccent = sectionAccent(def.tier);
    final depthColor = def.tier == TitleTier.starter
        ? const Color(0xFF142018)
        : const Color(0xFF101828);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? [
                  tierAccent.withValues(alpha: 0.14),
                  depthColor,
                  const Color(0xFF1A0505),
                ]
              : [
                  tierAccent.withValues(alpha: 0.06),
                  const Color(0x882A0707),
                ],
        ),
        border: Border.all(
          color: equipped
              ? equippedGold
              : tierAccent.withValues(alpha: unlocked ? 0.48 : 0.28),
          width: equipped ? 2 : 1.25,
        ),
        boxShadow: equipped
            ? [
                BoxShadow(
                  color: equippedGold.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : unlocked
                ? [
                    BoxShadow(
                      color: tierAccent.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
      ),
      child: child,
    );
  }

  static Widget iconFrame({
    required TitleDefinition def,
    required bool unlocked,
  }) {
    final tierAccent = sectionAccent(def.tier);
    final isElite = def.tier == TitleTier.elite;
    final shape = BorderRadius.circular(isElite ? 14 : 10);
    final size = isElite ? 48.0 : 42.0;
    final iconSize = isElite ? 24.0 : 22.0;

    final borderColor = switch (def.tier) {
      TitleTier.elite when unlocked => tierAccent,
      TitleTier.shop when unlocked => def.color.withValues(alpha: 0.75),
      TitleTier.starter || TitleTier.achievement when unlocked =>
        tierAccent.withValues(alpha: 0.62),
      _ => def.color.withValues(alpha: unlocked ? 0.75 : 0.25),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: unlocked
            ? RadialGradient(
                colors: [
                  Color.lerp(def.color, Colors.white, 0.3)!,
                  def.color,
                ],
              )
            : null,
        color: unlocked ? null : def.color.withValues(alpha: 0.1),
        border: Border.all(
          color: borderColor,
          width: isElite ? 2 : 1,
        ),
        boxShadow: isElite && unlocked
            ? [
                BoxShadow(
                  color: def.color.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(
        unlocked ? def.icon : Icons.lock_outline_rounded,
        color: unlocked ? Colors.white : Colors.white38,
        size: iconSize,
      ),
    );
  }
}
