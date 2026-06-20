import 'package:flutter/material.dart';

/// Nút menu lớn phong cách UNO — pill, gradient, responsive.
class MenuActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const MenuActionButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(m.radius),
        child: Ink(
          height: m.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.14)!,
                color,
                Color.lerp(color, Colors.black, 0.22)!,
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x44000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(m.radius),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: m.padH,
                  right: m.padH,
                  height: m.height * 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: m.padH),
                  child: Row(
                    children: [
                      _iconCircle(m),
                      SizedBox(width: m.gap),
                      Expanded(child: _titleBlock(m)),
                      _chevron(m),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCircle(_Metrics m) {
    return Container(
      width: m.iconBox,
      height: m.iconBox,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white30),
      ),
      child: Icon(icon, color: Colors.white, size: m.iconSize),
    );
  }

  Widget _titleBlock(_Metrics m) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: m.titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: m.subtitleGap),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: m.subtitleSize,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chevron(_Metrics m) {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      color: Colors.white.withValues(alpha: 0.85),
      size: m.chevronSize,
    );
  }
}

class _Metrics {
  final double height;
  final double radius;
  final double padH;
  final double gap;
  final double iconBox;
  final double iconSize;
  final double titleSize;
  final double subtitleSize;
  final double subtitleGap;
  final double chevronSize;

  const _Metrics({
    required this.height,
    required this.radius,
    required this.padH,
    required this.gap,
    required this.iconBox,
    required this.iconSize,
    required this.titleSize,
    required this.subtitleSize,
    required this.subtitleGap,
    required this.chevronSize,
  });

  factory _Metrics.of(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final scale = (h / 760).clamp(0.82, 1.12);

    final height = (72 * scale).clamp(62.0, 84.0);
    final titleSize = (18.5 * scale).clamp(16.0, 21.0);

    return _Metrics(
      height: height,
      radius: height / 2,
      padH: (18 * scale).clamp(14.0, 22.0),
      gap: (16 * scale).clamp(12.0, 20.0),
      iconBox: (50 * scale).clamp(44.0, 56.0),
      iconSize: (28 * scale).clamp(24.0, 32.0),
      titleSize: titleSize,
      subtitleSize: (12.5 * scale).clamp(11.0, 14.0),
      subtitleGap: 2,
      chevronSize: (16 * scale).clamp(14.0, 18.0),
    );
  }
}
