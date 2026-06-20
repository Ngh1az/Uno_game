import 'package:flutter/material.dart';

/// Thông báo floating card — dùng chung toàn app.
abstract final class AppSnack {
  static const gold = Color(0xFFFFC400);
  static const successGreen = Color(0xFF66BB6A);
  static const errorRed = Color(0xFFEF5350);
  static const infoBlue = Color(0xFF64B5F6);
  static const warningOrange = Color(0xFFFFB74D);

  static void show(
    BuildContext context, {
    required String message,
    String? detail,
    Color? accent,
    IconData? icon,
    Widget? trailing,
    Duration duration = const Duration(milliseconds: 2000),
    bool isError = false,
  }) {
    final color = accent ?? (isError ? errorRed : gold);
    final leading = icon ??
        (isError ? Icons.error_outline_rounded : Icons.check_circle_rounded);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: EdgeInsets.zero,
          content: _SnackCard(
            accent: color,
            icon: leading,
            message: message,
            detail: detail,
            trailing: trailing ??
                Icon(
                  isError
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_rounded,
                  color: isError ? const Color(0xFFEF9A9A) : gold,
                  size: 22,
                ),
          ),
        ),
      );
  }

  static void success(
    BuildContext context,
    String message, {
    String? detail,
    Color accent = gold,
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    show(
      context,
      message: message,
      detail: detail,
      accent: accent,
      icon: icon,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    show(
      context,
      message: message,
      isError: true,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? detail,
    IconData icon = Icons.info_outline_rounded,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    show(
      context,
      message: message,
      detail: detail,
      accent: infoBlue,
      icon: icon,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    show(
      context,
      message: message,
      accent: warningOrange,
      icon: Icons.block_rounded,
      trailing: const Icon(
        Icons.info_outline_rounded,
        color: warningOrange,
        size: 22,
      ),
      duration: duration,
    );
  }

  static void coins(BuildContext context, int amount) {
    success(
      context,
      'Nhận thưởng',
      detail: '+$amount xu UNO',
      accent: successGreen,
      icon: Icons.monetization_on_rounded,
    );
  }
}

class _SnackCard extends StatelessWidget {
  const _SnackCard({
    required this.accent,
    required this.icon,
    required this.message,
    this.detail,
    this.trailing,
  });

  final Color accent;
  final IconData icon;
  final String message;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final twoLine = detail != null && detail!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A0C0C),
            Color(0xFF1A0505),
            Color(0xFF120303),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(accent, Colors.white, 0.35)!,
                  accent,
                  Color.lerp(accent, Colors.black, 0.25)!,
                ],
              ),
              border: Border.all(
                color: Color.lerp(accent, Colors.white, 0.4)!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: twoLine
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
