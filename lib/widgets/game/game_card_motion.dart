import 'package:flutter/material.dart';

import '../../models/uno_card.dart';
import '../uno_card_widget.dart';

/// Lớp phủ hoạt ảnh lá bài bay giữa các vị trí trên bàn.
class GameCardMotionLayer extends StatefulWidget {
  const GameCardMotionLayer({super.key, required this.child});

  final Widget child;

  static GameCardMotionLayerState? of(BuildContext context) =>
      context.findAncestorStateOfType<GameCardMotionLayerState>();

  @override
  State<GameCardMotionLayer> createState() => GameCardMotionLayerState();
}

class GameCardMotionLayerState extends State<GameCardMotionLayer>
    with TickerProviderStateMixin {
  final List<_CardFlight> _flights = [];

  static Offset centerOf(GlobalKey key, {Offset fallback = Offset.zero}) {
    final ctx = key.currentContext;
    if (ctx == null) return fallback;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return fallback;
    final origin = box.localToGlobal(Offset.zero);
    return origin + Offset(box.size.width / 2, box.size.height / 2);
  }

  Future<void> fly({
    required UnoCard card,
    required Offset from,
    required Offset to,
    required double width,
    bool faceDown = false,
    Duration duration = const Duration(milliseconds: 360),
  }) async {
    if (!mounted) return;

    final layerBox = context.findRenderObject() as RenderBox?;
    if (layerBox == null) return;

    final localFrom = layerBox.globalToLocal(from);
    final localTo = layerBox.globalToLocal(to);

    final controller = AnimationController(vsync: this, duration: duration);
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    final flight = _CardFlight(
      card: card,
      from: localFrom,
      to: localTo,
      width: width,
      faceDown: faceDown,
      animation: curve,
    );

    setState(() => _flights.add(flight));
    try {
      await controller.forward();
    } finally {
      if (mounted) {
        setState(() => _flights.remove(flight));
      }
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_flights.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final flight in _flights)
                    _FlightSprite(flight: flight),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CardFlight {
  const _CardFlight({
    required this.card,
    required this.from,
    required this.to,
    required this.width,
    required this.faceDown,
    required this.animation,
  });

  final UnoCard card;
  final Offset from;
  final Offset to;
  final double width;
  final bool faceDown;
  final Animation<double> animation;

  double get height => width * UnoCardWidget.aspectRatio;
}

class _FlightSprite extends StatelessWidget {
  const _FlightSprite({required this.flight});

  final _CardFlight flight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, _) {
        final t = flight.animation.value;
        final pos = _arcLerp(flight.from, flight.to, t);
        final rot = (t - 0.5) * 0.22;
        final scale = 1.0 + 0.1 * (1 - (2 * t - 1).abs());

        return Positioned(
          left: pos.dx - flight.width / 2,
          top: pos.dy - flight.height / 2,
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(flight.width * 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: flight.faceDown
                    ? UnoCardBack(width: flight.width)
                    : UnoCardWidget(card: flight.card, width: flight.width),
              ),
            ),
          ),
        );
      },
    );
  }

  static Offset _arcLerp(Offset a, Offset b, double t) {
    final lift = (a.dy - b.dy).abs() * 0.12 + 42;
    final mid = Offset.lerp(a, b, 0.5)! - Offset(0, lift);
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * mid.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * mid.dy + t * t * b.dy,
    );
  }
}
