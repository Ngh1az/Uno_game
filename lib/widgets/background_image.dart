import 'package:flutter/material.dart';

/// Ảnh nền với fallback gradient khi thiếu file trong assets.
class BackgroundImage extends StatelessWidget {
  const BackgroundImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
  });

  final String assetPath;
  final BoxFit fit;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;

  static const _fallback = Color(0xFF2A0707);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (context, error, stackTrace) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A0E0E),
              _fallback,
              Color(0xFF1A0404),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}
