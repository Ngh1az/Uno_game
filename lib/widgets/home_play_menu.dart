import 'package:flutter/material.dart';

import 'home_layout.dart';
import 'menu_action_button.dart';

/// Nút chơi + hàng xếp hạng / bạn bè — gọn, đặt dưới khu nhiệm vụ.
class HomePlayMenu extends StatelessWidget {
  final VoidCallback onPlayOffline;
  final VoidCallback onPlayOnline;
  final VoidCallback onLeaderboard;
  final VoidCallback onFriends;
  final bool includePadding;

  const HomePlayMenu({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    required this.onLeaderboard,
    required this.onFriends,
    this.includePadding = true,
  });

  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: HomeLayout.maxContentWidth(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionTitle('CHƠI'),
            const SizedBox(height: 6),
            MenuActionButton(
              icon: Icons.smart_toy_rounded,
              title: 'Chơi với máy',
              color: const Color(0xFFD32F2F),
              onTap: onPlayOffline,
              compact: true,
            ),
            const SizedBox(height: gap),
            MenuActionButton(
              icon: Icons.public_rounded,
              title: 'Chơi online',
              color: const Color(0xFF1565C0),
              onTap: onPlayOnline,
              compact: true,
            ),
            const SizedBox(height: gap + 2),
            Row(
              children: [
                Expanded(
                  child: MenuActionButton(
                    icon: Icons.emoji_events_rounded,
                    title: 'Xếp hạng',
                    color: const Color(0xFFE65100),
                    onTap: onLeaderboard,
                    compact: true,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: MenuActionButton(
                    icon: Icons.people_rounded,
                    title: 'Bạn bè',
                    color: const Color(0xFF6A1B9A),
                    onTap: onFriends,
                    compact: true,
                  ),
                ),
              ],
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

  Widget _sectionTitle(String label) {
    return Row(
      children: [
        Expanded(child: _goldLine()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
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
