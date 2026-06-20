import 'package:flutter/material.dart';

/// Chân trang Home: phiên bản + liên kết nhỏ.
class HomeFooter extends StatelessWidget {
  final VoidCallback onRules;
  final VoidCallback onTerms;

  const HomeFooter({
    super.key,
    required this.onRules,
    required this.onTerms,
  });

  static const _textColor = Color(0xFFFFF8E1); // vàng nhạt, dễ đọc trên nền đỏ

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _link('Luật chơi', onRules),
              Text('  ·  ', style: _baseStyle(opacity: 0.55, size: 12)),
              _link('Điều khoản', onTerms),
            ],
          ),
          const SizedBox(height: 6),
          Text('v1.0.0', style: _baseStyle(opacity: 0.5, size: 11)),
        ],
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: _baseStyle(opacity: 0.6, size: 12.5).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: _textColor.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  /// Sans-serif bo tròn, đồng bộ tinh thần với tên người chơi trên top bar.
  static TextStyle _baseStyle({required double opacity, required double size}) {
    return TextStyle(
      color: _textColor.withValues(alpha: opacity),
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.25,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
  }
}
