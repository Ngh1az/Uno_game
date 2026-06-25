import 'package:flutter/material.dart';

import '../friends/friend_models.dart';
import '../friends/friends_service.dart';
import '../navigation/app_navigator.dart';
import '../online/auth_service.dart';
import '../online/room_service.dart';
import '../titles/title_definition.dart';
import '../titles/title_store.dart';
import '../online/waiting_room_session.dart';
import '../widgets/app_snack.dart';
import '../widgets/game/game_theme.dart';
import '../widgets/title_name_text.dart';
import '../widgets/user_avatar.dart';
import '../screens/online/room_screen.dart';

/// Lắng nghe lời mời chơi realtime — popup trên mọi màn hình (global navigator).
class RoomInviteListener extends StatefulWidget {
  const RoomInviteListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<RoomInviteListener> createState() => _RoomInviteListenerState();
}

class _RoomInviteListenerState extends State<RoomInviteListener> {
  final _service = FriendsService();
  final _roomService = RoomService();
  final _shown = <String>{};
  bool _joining = false;
  bool _dialogOpen = false;

  GlobalKey<NavigatorState> get _navKey => widget.navigatorKey ?? rootNavigatorKey;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null || AuthService().isGuest) return widget.child;

    return StreamBuilder<List<RoomInvite>>(
      stream: _service.watchRoomInvites(),
      builder: (context, snap) {
        final invites = snap.data ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowInvite(invites);
        });
        return widget.child;
      },
    );
  }

  BuildContext? get _dialogContext {
    final ctx = _navKey.currentContext;
    if (ctx != null && ctx.mounted) return ctx;
    return null;
  }

  void _maybeShowInvite(List<RoomInvite> invites) {
    if (!mounted || _joining || _dialogOpen) return;

    final fresh = invites
        .where((i) => !_shown.contains(i.id) && !i.isExpired)
        .toList();
    if (fresh.isEmpty) return;

    final dialogContext = _dialogContext;
    if (dialogContext == null) return;

    final invite = fresh.first;
    _shown.add(invite.id);
    _dialogOpen = true;

    showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _RoomInviteDialog(
        invite: invite,
        onDismiss: () async {
          Navigator.of(ctx).pop();
          await _service.dismissRoomInvite(invite.id);
        },
        onAccept: () async {
          Navigator.of(ctx).pop();
          await _acceptInvite(invite);
        },
      ),
    ).whenComplete(() {
      if (mounted) _dialogOpen = false;
    });
  }

  Future<void> _acceptInvite(RoomInvite invite) async {
    setState(() => _joining = true);
    try {
      await _roomService.joinRoom(
        code: invite.roomCode,
        name: AuthService().displayName,
        profile: RoomPlayerProfile(
          photoUrl: AuthService().photoUrl,
          equippedTitleId: TitleStore.instance.equippedId,
        ),
      );
      await _service.dismissRoomInvite(invite.id);

      final navContext = _dialogContext;
      if (navContext == null || !navContext.mounted) return;

      WaitingRoomSession.instance.bind(invite.roomCode);
      Navigator.of(navContext).push(
        MaterialPageRoute(builder: (_) => RoomScreen(code: invite.roomCode)),
      );
    } on RoomException catch (e) {
      final navContext = _dialogContext;
      if (navContext != null && navContext.mounted) {
        AppSnack.error(navContext, e.message);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
}

class _RoomInviteDialog extends StatelessWidget {
  const _RoomInviteDialog({
    required this.invite,
    required this.onDismiss,
    required this.onAccept,
  });

  final RoomInvite invite;
  final VoidCallback onDismiss;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final code = invite.roomCode;
    final spacedCode = code.split('').join(' ');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.15,
            colors: [Color(0xFF4A1414), Color(0xFF1A0505)],
          ),
          border: Border.all(color: GameTheme.gold.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GameTheme.gold.withValues(alpha: 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: GameTheme.gold.withValues(alpha: 0.18),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: UserAvatar(
                  displayName: invite.fromName,
                  radius: 34,
                ),
              ),
              const SizedBox(height: 16),
              const TitleNamePlain(
                name: 'Lời mời chơi',
                tier: TitleTier.elite,
                accent: GameTheme.gold,
                fontSize: 22,
                shimmer: true,
              ),
              const SizedBox(height: 10),
              Text(
                invite.fromName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'mời bạn vào phòng',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: GameTheme.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  spacedCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onDismiss,
                      child: const Text(
                        'Bỏ qua',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: GameTheme.gold,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: GameTheme.gold, width: 1.5),
                        ),
                      ),
                      onPressed: onAccept,
                      icon: const Icon(Icons.sports_esports_rounded, size: 20),
                      label: const Text(
                        'Vào phòng',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
