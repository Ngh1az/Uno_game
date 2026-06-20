import 'package:flutter/material.dart';

import '../titles/title_definition.dart';

Color _brightAccent(Color color, [double mix = 0.45]) =>
    Color.lerp(color, Colors.white, mix)!;

/// Tên danh hiệu — hiệu ứng theo cấp (tập sự → boss online).
class TitleNameText extends StatelessWidget {
  const TitleNameText({
    super.key,
    required this.title,
    this.fontSize = 16,
    this.shimmer = false,
    this.shimmerDuration,
    this.maxLines = 1,
    this.outlineWidth = 2.5,
    this.letterSpacing = 0,
    this.softOutline = false,
  });

  final TitleDefinition title;
  final double fontSize;
  final bool shimmer;
  final Duration? shimmerDuration;
  final int maxLines;
  final double outlineWidth;
  final double letterSpacing;
  /// Viền mỏng bằng shadow thay vì stroke dày — dễ đọc hơn trên Home.
  final bool softOutline;

  TextStyle get _baseStyle => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.15,
        letterSpacing: letterSpacing,
        color: Colors.white,
      );

  List<Shadow> get _softShadows => const [
        Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1)),
        Shadow(color: Color(0x88000000), blurRadius: 8),
      ];

  @override
  Widget build(BuildContext context) {
    if (shimmer) {
      return _ShimmerTitleName(
        name: title.name,
        accent: title.color,
        tier: title.tier,
        fontSize: fontSize,
        maxLines: maxLines,
        duration: shimmerDuration,
        outlineWidth: outlineWidth,
        letterSpacing: letterSpacing,
        softOutline: softOutline,
      );
    }

    final style = _baseStyle;

    switch (title.tier) {
      case TitleTier.elite:
        final bright = _brightAccent(title.color, 0.5);
        return _gradientName(
          title.name,
          style,
          [bright, Colors.white, const Color(0xFFFFF8E1), bright],
          maxLines,
          outline: !softOutline,
        );
      case TitleTier.shop:
        return _gradientName(
          title.name,
          style,
          [
            const Color(0xFFFFF8E1),
            const Color(0xFFFFD54F),
            const Color(0xFFFFB300),
            const Color(0xFFFFF8E1),
          ],
          maxLines,
          outline: !softOutline,
        );
      case TitleTier.achievement:
        final bright = _brightAccent(title.color);
        return _gradientName(
          title.name,
          style,
          [Colors.white, bright, Colors.white],
          maxLines,
          outline: !softOutline,
        );
      case TitleTier.starter:
        if (softOutline) {
          return Text(
            title.name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              shadows: [
                ..._softShadows,
                Shadow(
                  color: title.color.withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
          );
        }
        return _outlinedText(
          title.name,
          style.copyWith(
            shadows: [
              Shadow(color: title.color.withValues(alpha: 0.75), blurRadius: 10),
              const Shadow(color: Colors.black54, blurRadius: 3),
            ],
          ),
          maxLines,
        );
    }
  }

  Widget _gradientName(
    String name,
    TextStyle style,
    List<Color> colors,
    int maxLines, {
    bool outline = false,
  }) {
    final textStyle = softOutline
        ? style.copyWith(shadows: _softShadows)
        : style;

    final gradientText = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(bounds),
      child: Text(
        name,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );

    if (!outline) return gradientText;

    return Stack(
      children: [
        Text(
          name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..color = const Color(0xCC000000),
          ),
        ),
        gradientText,
      ],
    );
  }

  Widget _outlinedText(String name, TextStyle style, int maxLines) {
    return Stack(
      children: [
        Text(
          name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..color = const Color(0xAA000000),
          ),
        ),
        Text(
          name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }
}

class _ShimmerTitleName extends StatefulWidget {
  const _ShimmerTitleName({
    required this.name,
    required this.accent,
    required this.tier,
    required this.fontSize,
    required this.maxLines,
    this.duration,
    this.outlineWidth = 2.5,
    this.letterSpacing = 0,
    this.softOutline = false,
  });

  final String name;
  final Color accent;
  final TitleTier tier;
  final double fontSize;
  final int maxLines;
  final Duration? duration;
  final double outlineWidth;
  final double letterSpacing;
  final bool softOutline;

  @override
  State<_ShimmerTitleName> createState() => _ShimmerTitleNameState();
}

class _ShimmerTitleNameState extends State<_ShimmerTitleName>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  List<Color> _shimmerColors() {
    final bright = _brightAccent(widget.accent, 0.55);
    final mid = _brightAccent(widget.accent, 0.25);
    switch (widget.tier) {
      case TitleTier.starter:
        return [mid, bright, Colors.white, bright, mid];
      case TitleTier.shop:
        return [
          const Color(0xFFFFF8E1),
          const Color(0xFFFFD54F),
          Colors.white,
          const Color(0xFFFFB300),
          const Color(0xFFFFF8E1),
        ];
      case TitleTier.achievement:
        return [Colors.white, bright, widget.accent, bright, Colors.white];
      case TitleTier.elite:
        return [mid, bright, Colors.white, const Color(0xFFFFF8E1), mid];
    }
  }

  Duration get _duration =>
      widget.duration ?? const Duration(milliseconds: 4500);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _softShadows = [
    Shadow(color: Color(0xBB000000), blurRadius: 4, offset: Offset(0, 1)),
    Shadow(color: Color(0x77000000), blurRadius: 8),
  ];

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w900,
      height: 1.15,
      letterSpacing: widget.letterSpacing,
      color: Colors.white,
      shadows: widget.softOutline ? _softShadows : null,
    );
    final colors = _shimmerColors();

    final shimmerChild = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final start = -1.6 + t * 3.2;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(start, 0),
              end: Alignment(start + 1.0, 0),
              colors: colors,
              stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        widget.name,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );

    if (widget.softOutline) return shimmerChild;

    return Stack(
      children: [
        Text(
          widget.name,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: textStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = widget.outlineWidth
              ..color = const Color(0xCC000000),
          ),
        ),
        shimmerChild,
      ],
    );
  }
}

/// Tên danh hiệu từ chuỗi + tier (khi chưa có full TitleDefinition).
class TitleNamePlain extends StatelessWidget {
  const TitleNamePlain({
    super.key,
    required this.name,
    required this.tier,
    required this.accent,
    this.fontSize = 16,
    this.shimmer = false,
  });

  final String name;
  final TitleTier tier;
  final Color accent;
  final double fontSize;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    return TitleNameText(
      title: TitleDefinition(
        id: '_',
        name: name,
        description: '',
        icon: Icons.star,
        color: accent,
        tier: tier,
      ),
      fontSize: fontSize,
      shimmer: shimmer,
    );
  }
}
