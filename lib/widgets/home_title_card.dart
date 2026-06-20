import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../titles/title_definition.dart';
import '../titles/title_store.dart';
import 'title_name_text.dart';

/// Thẻ danh hiệu trên Home — khung vàng nổi bật, tên danh hiệu là hero.
class HomeTitleCard extends StatefulWidget {
  const HomeTitleCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<HomeTitleCard> createState() => _HomeTitleCardState();
}

class _HomeTitleCardState extends State<HomeTitleCard>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD54F);
  static const _goldDeep = Color(0xFFFFB300);

  Color _brightBadge(Color color) => Color.lerp(color, Colors.white, 0.45)!;

  static const _labelStyle = TextStyle(
    color: Color(0xFFF8F8F8),
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    shadows: [
      Shadow(color: Color(0x99FFD54F), blurRadius: 8),
      Shadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  late final AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  bool _isElite(TitleDefinition? title) => title?.tier == TitleTier.elite;

  List<BoxShadow> _frameShadows(bool elite, double pulse, Color badge) {
    final bright = _brightBadge(badge);
    final shadows = <BoxShadow>[
      BoxShadow(
        color: (elite ? bright : _gold).withValues(alpha: elite ? 0.5 : 0.45),
        blurRadius: elite ? 22 : 18,
        offset: const Offset(0, 6),
      ),
      const BoxShadow(
        color: Color(0x66000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ];
    if (elite) {
      shadows.insertAll(0, [
        BoxShadow(
          color: badge.withValues(alpha: 0.42 + 0.18 * pulse),
          blurRadius: 8 + 6 * pulse,
          spreadRadius: 0.5 + 1.5 * pulse,
        ),
        BoxShadow(
          color: bright.withValues(alpha: 0.32 + 0.14 * pulse),
          blurRadius: 24 + 8 * pulse,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: badge.withValues(alpha: 0.28),
          blurRadius: 14,
          spreadRadius: 0.5,
        ),
      ]);
    }
    return shadows;
  }

  List<Color> _outerBorderGradient(Color badge) {
    final bright = _brightBadge(badge);
    final deep = Color.lerp(badge, const Color(0xFF1A0505), 0.45)!;
    return [bright, badge, deep, bright];
  }

  @override
  Widget build(BuildContext context) {
    final store = TitleStore.instance;
    final equipped = store.equippedTitle;
    final news = store.newUnlockCount;
    final accent = equipped?.color ?? _gold;
    final elite = _isElite(equipped);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedBuilder(
            animation: _sparkle,
            builder: (context, _) {
              final t = _sparkle.value;
              final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (elite)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: 0.4 + 0.14 * pulse,
                                ),
                                blurRadius: 10 + 4 * pulse,
                                spreadRadius: 2 + pulse,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _buildCardShell(
                    t: t,
                    pulse: pulse,
                    accent: accent,
                    elite: elite,
                    equipped: equipped,
                    store: store,
                    news: news,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCardShell({
    required double t,
    required double pulse,
    required Color accent,
    required bool elite,
    required TitleDefinition? equipped,
    required TitleStore store,
    required int news,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: elite
              ? _outerBorderGradient(accent)
              : const [
                  Color(0xFFFFF8E1),
                  _gold,
                  _goldDeep,
                  Color(0xFFFFF8E1),
                ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
        boxShadow: _frameShadows(elite, pulse, accent),
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (elite)
            Positioned.fill(
              child: IgnorePointer(
                child: _borderSparkles(t, accent),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1A0505),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  ..._innerBackground(accent: accent, elite: elite),
                  if (elite)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _innerEliteShimmer(t, accent),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: equipped != null
                        ? _equippedBody(equipped, news)
                        : _emptyBody(store, news),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nền trong khung — ember đáy, spotlight medal, bokeh nhẹ, vignette.
  List<Widget> _innerBackground({required Color accent, required bool elite}) {
    final emberStrong = elite ? 0.24 : 0.13;
    final emberMid = elite ? 0.09 : 0.05;
    final spotStrong = elite ? 0.34 : 0.2;
    final spotMid = elite ? 0.13 : 0.07;
    final bokehAlpha = elite ? 0.08 : 0.045;

    return [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2A0C0C),
                Color(0xFF1A0505),
                Color(0xFF120303),
              ],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: const Alignment(0, -0.2),
              colors: [
                accent.withValues(alpha: emberStrong),
                accent.withValues(alpha: emberMid),
                Colors.transparent,
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.08),
              radius: 0.78,
              colors: [
                accent.withValues(alpha: spotStrong),
                accent.withValues(alpha: spotMid),
                Colors.transparent,
              ],
              stops: const [0.0, 0.36, 1.0],
            ),
          ),
        ),
      ),
      Positioned(
        right: -18,
        top: 6,
        child: _innerBokehOrb(accent, bokehAlpha, 72),
      ),
      Positioned(
        right: 36,
        bottom: 4,
        child: _innerBokehOrb(
          Color.lerp(accent, Colors.white, 0.25)!,
          bokehAlpha * 0.75,
          48,
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: elite ? 0.22 : 0.16),
              ],
              stops: const [0.52, 1.0],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.black.withValues(alpha: 0.14),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _innerBokehOrb(Color color, double alpha, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha * 0.55),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: alpha),
              blurRadius: size * 0.45,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }

  /// Hạt sáng chạy dọc viền khung — màu theo badge (elite).
  Widget _borderSparkles(double t, Color badge) {
    final bright = _brightBadge(badge);
    const anchors = <Offset>[
      Offset(0.06, 0.04),
      Offset(0.32, 0.0),
      Offset(0.58, 0.02),
      Offset(0.86, 0.06),
      Offset(0.98, 0.34),
      Offset(0.94, 0.62),
      Offset(0.72, 0.98),
      Offset(0.38, 0.96),
      Offset(0.1, 0.88),
      Offset(0.0, 0.52),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < anchors.length; i++)
              Builder(
                builder: (context) {
                  final phase = (t + i / anchors.length) % 1.0;
                  final glow = 0.2 + 0.65 * math.sin(phase * math.pi * 2);
                  final size = 5.0 + 3.0 * glow;
                  return Positioned(
                    left: anchors[i].dx * w - size / 2,
                    top: anchors[i].dy * h - size / 2,
                    child: Opacity(
                      opacity: glow.clamp(0.0, 1.0),
                      child: Icon(
                        i.isEven ? Icons.auto_awesome : Icons.star_rounded,
                        size: size,
                        color: Color.lerp(
                          badge,
                          bright,
                          0.25 + 0.55 * glow,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _innerEliteShimmer(double t, Color badge) {
    final sweep = -1.0 + t * 2.2;
    final bright = _brightBadge(badge);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(sweep, -0.3),
          end: Alignment(sweep + 0.55, 0.3),
          colors: [
            Colors.transparent,
            badge.withValues(alpha: 0.1),
            bright.withValues(alpha: 0.08),
            badge.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        ),
      ),
    );
  }

  Widget _equippedBody(TitleDefinition title, int news) {
    return Row(
      children: [
        _medal(title.icon, title.color, elite: title.tier == TitleTier.elite),
        const SizedBox(width: 14),
        Expanded(child: _titleHero(title)),
        _openButton(news),
      ],
    );
  }

  Widget _emptyBody(TitleStore store, int news) {
    return Row(
      children: [
        _medal(Icons.workspace_premium_rounded, _gold),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('DANH HIỆU', style: _labelStyle),
              const SizedBox(height: 4),
              const Text(
                'Khám phá ngay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: [
                    Shadow(color: Color(0x99FFB300), blurRadius: 10),
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${store.unlockedCount}/${store.catalog.length} đã mở khóa',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _openButton(news),
      ],
    );
  }

  Widget _titleHero(TitleDefinition title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('DANH HIỆU', style: _labelStyle),
        const SizedBox(height: 4),
        TitleNameText(
          title: title,
          fontSize: 20,
          shimmer: true,
          shimmerDuration: const Duration(milliseconds: 5500),
          softOutline: true,
          outlineWidth: 1.5,
          letterSpacing: 0.25,
        ),
        const SizedBox(height: 7),
        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [title.color, title.color.withValues(alpha: 0.2)],
            ),
            boxShadow: [
              BoxShadow(
                color: title.color.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
              if (title.tier == TitleTier.elite)
                BoxShadow(
                  color: title.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _medal(IconData icon, Color color, {bool elite = false}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ),
        border: Border.all(
          color: elite ? _brightBadge(color) : _gold,
          width: elite ? 3 : 2.5,
        ),
        boxShadow: [
          if (elite) ...[
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: _brightBadge(color).withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
          BoxShadow(
            color: color.withValues(alpha: elite ? 0.65 : 0.55),
            blurRadius: elite ? 14 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
        shadows: elite
            ? [
                Shadow(color: _brightBadge(color).withValues(alpha: 0.85), blurRadius: 10),
                Shadow(color: color.withValues(alpha: 0.55), blurRadius: 6),
                const Shadow(color: Color(0x88000000), blurRadius: 3),
              ]
            : null,
      ),
    );
  }

  Widget _openButton(int news) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF59D), _goldDeep],
            ),
            border: Border.all(color: Colors.white54),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFB300),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF3E2723),
            size: 24,
          ),
        ),
        if (news > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$news',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
