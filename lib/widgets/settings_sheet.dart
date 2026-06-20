import 'package:flutter/material.dart';

import '../app_settings.dart';
import 'uno_circle_button.dart';

/// Bảng cài đặt dạng bottom sheet (âm thanh, ngôn ngữ, thông báo).
class SettingsSheet {
  SettingsSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A0505),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: AppSettings.instance,
          builder: (ctx, _) {
            final settings = AppSettings.instance;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cài đặt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      UnoCircleButton(
                        icon: Icons.close,
                        label: '',
                        showLabel: false,
                        size: 42,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _settingButton(
                        icon: settings.soundEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        label: 'Âm thanh',
                        active: settings.soundEnabled,
                        onTap: () => settings.setSoundEnabled(
                          !settings.soundEnabled,
                        ),
                      ),
                      _settingButton(
                        icon: Icons.language,
                        label: settings.languageLabel,
                        active: true,
                        onTap: () => _pickLanguage(ctx),
                      ),
                      _settingButton(
                        icon: settings.notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        label: 'Thông báo',
                        active: settings.notificationsEnabled,
                        onTap: () => settings.setNotificationsEnabled(
                          !settings.notificationsEnabled,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _settingButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: UnoCircleButton(
        icon: icon,
        label: label,
        size: 64,
        onTap: onTap,
      ),
    );
  }

  static Future<void> _pickLanguage(BuildContext context) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A0707),
        title: const Text(
          'Ngôn ngữ',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languageTile(ctx, 'vi', 'Tiếng Việt', settings.languageCode),
            _languageTile(ctx, 'en', 'English', settings.languageCode),
          ],
        ),
      ),
    );
    if (picked != null) settings.setLanguage(picked);
  }

  static Widget _languageTile(
    BuildContext context,
    String code,
    String label,
    String current,
  ) {
    final selected = code == current;
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: selected
          ? const Icon(Icons.check, color: Color(0xFFFFC400))
          : null,
      onTap: () => Navigator.of(context).pop(code),
    );
  }
}
