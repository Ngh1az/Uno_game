import 'package:flutter/material.dart';

import 'home_layout.dart';
import 'menu_action_button.dart';

/// Hai nút chọn chế độ chơi — căn giữa, co giãn theo màn hình.
class HomePlayMenu extends StatelessWidget {
  final VoidCallback onPlayOffline;
  final VoidCallback onPlayOnline;
  final bool includePadding;
  final bool compact;

  const HomePlayMenu({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    this.includePadding = true,
    this.compact = false,
  });

  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final gap = compact
        ? 8.0
        : (size.height * 0.018).clamp(12.0, 18.0);

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: HomeLayout.maxContentWidth(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionTitle(),
            SizedBox(height: gap * 0.75),
            MenuActionButton(
              icon: Icons.smart_toy_rounded,
              title: 'Chơi với máy',
              color: const Color(0xFFD32F2F),
              onTap: onPlayOffline,
            ),
            SizedBox(height: gap),
            MenuActionButton(
              icon: Icons.public_rounded,
              title: 'Chơi online',
              color: const Color(0xFF1565C0),
              onTap: onPlayOnline,
            ),
          ],
        ),
      ),
    );

    if (!includePadding) return content;

    return Padding(
      padding: HomeLayout.contentPadding(context),
      child: content,
    );
  }

  Widget _sectionTitle() {
    return Row(
      children: [
        Expanded(child: _goldLine()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'CHỌN CHẾ ĐỘ',
            style: TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
        Expanded(child: _goldLine()),
      ],
    );
  }

  Widget _goldLine() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _gold.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
