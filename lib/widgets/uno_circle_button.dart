import 'package:flutter/material.dart';

/// Nút tròn phong cách UNO: đỏ bóng + viền vàng phát sáng.
/// Vẽ bằng code để không phụ thuộc PNG nền đen.
class UnoCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  /// Tỉ lệ kích thước biểu tượng so với đường kính nút (0..1).
  final double iconScale;
  /// Ẩn nhãn bên dưới (dùng cho nút góc chỉ cần icon).
  final bool showLabel;

  const UnoCircleButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 56,
    this.iconScale = 0.58,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAAFFC107),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 1.1,
                colors: [Color(0xFFE53935), Color(0xFF8B0000)],
              ),
              border: Border.all(color: const Color(0xFFFFD54F), width: 3),
            ),
            child: Stack(
              children: [
                // Highlight bóng 3D.
                Positioned(
                  top: size * 0.08,
                  left: size * 0.15,
                  child: Container(
                    width: size * 0.45,
                    height: size * 0.22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size),
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    icon,
                    color: const Color(0xFFFFD54F),
                    size: size * iconScale,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showLabel && label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
