import 'package:flutter/material.dart';

import '../background_image.dart';
import 'game_table_ring_painter.dart';

/// Nền premium đỏ–vàng đồng bộ Home/Titles.
class GameTableShell extends StatelessWidget {
  const GameTableShell({super.key, required this.child, this.showRing = true});

  final Widget child;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF2A0707)),
        const BackgroundImage(
          assetPath: 'assets/images/background/homescreen.png',
          fit: BoxFit.cover,
          alignment: Alignment(0, -0.12),
          color: Color(0xAAFFFFFF),
          colorBlendMode: BlendMode.modulate,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0, 0.25),
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x880D0202),
                Color(0xDD0D0202),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        if (showRing)
          const Positioned.fill(child: CustomPaint(painter: GameTableRingPainter())),
        child,
      ],
    );
  }
}
