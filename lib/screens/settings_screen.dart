import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../game/game_limits.dart';
import '../online/auth_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/sign_out_dialog.dart';
import '../widgets/uno_circle_button.dart';
import '../widgets/user_avatar.dart';

/// Màn cài đặt chi tiết (mở từ Home).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _bg = Color(0xFF1A0505);
  static const _card = Color(0xFF2A0707);
  static const _accent = Color(0xFFFFC400);
  static const _comingSoonLabel = 'Sắp ra mắt';

  static void _comingSoon(BuildContext context) {
    AppSnack.info(context, _comingSoonLabel, icon: Icons.hourglass_top_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppSettings.instance,
          builder: (context, _) {
            final s = AppSettings.instance;
            return Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _section(
                        'Tài khoản',
                        [
                          _accountTile(auth),
                        ],
                      ),
                      _section(
                        'Âm thanh',
                        [
                          _switchTile(
                            context,
                            icon: Icons.volume_up,
                            title: 'Bật âm thanh',
                            value: s.soundEnabled,
                            onChanged: s.setSoundEnabled,
                            comingSoon: true,
                          ),
                          _sliderTile(
                            icon: Icons.tune,
                            title: 'Âm lượng',
                            value: s.soundVolume,
                            enabled: s.soundEnabled,
                            onChanged: s.setSoundVolume,
                            comingSoon: true,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.music_note,
                            title: 'Nhạc nền',
                            value: s.musicEnabled,
                            enabled: s.soundEnabled,
                            onChanged: s.setMusicEnabled,
                            comingSoon: true,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.graphic_eq,
                            title: 'Hiệu ứng âm thanh',
                            value: s.sfxEnabled,
                            enabled: s.soundEnabled,
                            onChanged: s.setSfxEnabled,
                            comingSoon: true,
                          ),
                        ],
                      ),
                      _section(
                        'Thông báo',
                        [
                          _switchTile(
                            context,
                            icon: Icons.notifications,
                            title: 'Bật thông báo',
                            value: s.notificationsEnabled,
                            onChanged: s.setNotificationsEnabled,
                            comingSoon: true,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.meeting_room,
                            title: 'Lời mời phòng',
                            value: s.roomInviteNotifications,
                            enabled: s.notificationsEnabled,
                            onChanged: s.setRoomInviteNotifications,
                            comingSoon: true,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.swap_horiz,
                            title: 'Đến lượt bạn',
                            value: s.turnNotifications,
                            enabled: s.notificationsEnabled,
                            onChanged: s.setTurnNotifications,
                            comingSoon: true,
                          ),
                        ],
                      ),
                      _section(
                        'Ngôn ngữ',
                        [
                          _choiceTile(
                            context,
                            icon: Icons.language,
                            title: 'Ngôn ngữ',
                            subtitle: s.languageLabel,
                            onTap: () => _pickLanguage(context),
                            comingSoon: true,
                          ),
                        ],
                      ),
                      _section(
                        'Trò chơi',
                        [
                          _sliderTile(
                            icon: Icons.smart_toy,
                            title: 'Số bot mặc định',
                            value: (s.defaultBotCount - GameLimits.minBots) /
                                (GameLimits.maxBots - GameLimits.minBots),
                            label:
                                '${s.defaultBotCount} bot · ${s.defaultBotCount + 1} người',
                            enabled: true,
                            onChanged: (v) => s.setDefaultBotCount(
                              GameLimits.minBots +
                                  (v * (GameLimits.maxBots - GameLimits.minBots))
                                      .round(),
                            ),
                          ),
                          _choiceTile(
                            context,
                            icon: Icons.speed,
                            title: 'Tốc độ bot',
                            subtitle: s.botSpeedLabel,
                            onTap: () => _pickBotSpeed(context),
                          ),
                          _switchTile(
                            context,
                            icon: Icons.lightbulb_outline,
                            title: 'Gợi ý lá có thể đánh',
                            value: s.showPlayableHints,
                            onChanged: s.setShowPlayableHints,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.campaign,
                            title: 'Tự động gọi UNO',
                            value: s.autoUnoCall,
                            onChanged: s.setAutoUnoCall,
                          ),
                        ],
                      ),
                      _section(
                        'Hiển thị',
                        [
                          _switchTile(
                            context,
                            icon: Icons.animation,
                            title: 'Hiệu ứng lá bài',
                            value: s.cardAnimations,
                            onChanged: s.setCardAnimations,
                          ),
                          _switchTile(
                            context,
                            icon: Icons.vibration,
                            title: 'Rung khi đến lượt',
                            value: s.vibrationEnabled,
                            onChanged: s.setVibrationEnabled,
                            comingSoon: true,
                          ),
                        ],
                      ),
                      _section(
                        'Khác',
                        [
                          _choiceTile(
                            context,
                            icon: Icons.info_outline,
                            title: 'Phiên bản',
                            subtitle: '1.0.0',
                            onTap: () {},
                            showChevron: false,
                          ),
                          _choiceTile(
                            context,
                            icon: Icons.description_outlined,
                            title: 'Điều khoản sử dụng',
                            onTap: () => _comingSoon(context),
                            comingSoon: true,
                          ),
                          _choiceTile(
                            context,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Quyền riêng tư',
                            onTap: () => _comingSoon(context),
                            comingSoon: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _signOutButton(context, auth),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          UnoCircleButton(
            icon: Icons.arrow_back,
            label: '',
            showLabel: false,
            size: 44,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Cài đặt',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: _accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(AuthService auth) {
    final name = auth.displayName;
    final isGuest = auth.isGuest;
    return ListTile(
      leading: UserAvatar(
        photoUrl: auth.photoUrl,
        displayName: name,
        radius: 22,
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isGuest ? 'Tài khoản khách' : 'Đăng nhập Google',
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool comingSoon = false,
  }) {
    return _tileShell(
      icon: icon,
      title: title,
      subtitle: null,
      trailing: comingSoon
          ? _comingSoonBadge()
          : Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: _accent,
            ),
      enabled: enabled && !comingSoon,
      onTap: comingSoon ? () => _comingSoon(context) : null,
    );
  }

  Widget _sliderTile({
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    String? label,
    bool enabled = true,
    bool comingSoon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Opacity(
        opacity: enabled && !comingSoon ? 1 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                if (comingSoon)
                  _comingSoonBadge()
                else if (label != null)
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
            Slider(
              value: value,
              onChanged: enabled && !comingSoon ? onChanged : null,
              activeColor: _accent,
              inactiveColor: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showChevron = true,
    bool comingSoon = false,
  }) {
    return _tileShell(
      icon: icon,
      title: title,
      subtitle: comingSoon ? null : subtitle,
      trailing: comingSoon
          ? _comingSoonBadge()
          : showChevron
              ? const Icon(Icons.chevron_right, color: Colors.white38)
              : null,
      onTap: comingSoon ? () => _comingSoon(context) : onTap,
      enabled: !comingSoon || showChevron == false,
    );
  }

  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        _comingSoonLabel,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _tileShell({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        leading: Icon(icon, color: _accent, size: 22),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              )
            : null,
        trailing: trailing,
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _signOutButton(BuildContext context, AuthService auth) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF8A80),
          side: const BorderSide(color: Color(0x66FF8A80)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () async {
          if (!await confirmSignOut(context)) return;
          await auth.signOut();
          if (context.mounted) Navigator.of(context).pop();
        },
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'Đăng xuất',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static Future<void> _pickLanguage(BuildContext context) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Ngôn ngữ', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogTile(ctx, 'vi', 'Tiếng Việt', settings.languageCode),
            _dialogTile(ctx, 'en', 'English', settings.languageCode),
          ],
        ),
      ),
    );
    if (picked != null) settings.setLanguage(picked);
  }

  static Future<void> _pickBotSpeed(BuildContext context) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<BotSpeed>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Tốc độ bot',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BotSpeed.values.map((speed) {
            final label = switch (speed) {
              BotSpeed.slow => 'Chậm',
              BotSpeed.normal => 'Bình thường',
              BotSpeed.fast => 'Nhanh',
            };
            return _dialogTile(
              ctx,
              speed.name,
              label,
              settings.botSpeed.name,
              onPick: () => Navigator.of(ctx).pop(speed),
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null) settings.setBotSpeed(picked);
  }

  static Widget _dialogTile(
    BuildContext context,
    String code,
    String label,
    String current, {
    VoidCallback? onPick,
  }) {
    final selected = code == current;
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: selected
          ? const Icon(Icons.check, color: _accent)
          : null,
      onTap: onPick ?? () => Navigator.of(context).pop(code),
    );
  }
}

