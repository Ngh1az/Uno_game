import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../notifications/in_app_notifications.dart';
import '../friends/active_room_tracker.dart';
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
  int _showRetries = 0;
  List<RoomInvite> _pendingInvites = const [];
  late final StreamSubscription<User?> _authSub;

  static const _maxShowRetries = 40;

  GlobalKey<NavigatorState> get _navKey => widget.navigatorKey ?? rootNavigatorKey;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null) return widget.child;

    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        return StreamBuilder<List<RoomInvite>>(
          stream: _service.watchRoomInvites(),
          builder: (context, snap) {
            if (snap.hasError && kDebugMode) {
              debugPrint('watchRoomInvites error: ${snap.error}');
            }
            final invites = snap.data ?? [];
            _pendingInvites = invites;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_maybeShowInvite());
            });
            return widget.child;
          },
        );
      },
    );
  }

  BuildContext? get _dialogContext {
    final ctx = _navKey.currentContext;
    if (ctx != null && ctx.mounted) return ctx;
    return null;
  }

  Future<void> _maybeShowInvite() async {
    if (!mounted || _joining || _dialogOpen) return;
    if (!InAppNotifications.roomInvites) return;

    final myUid = AuthService().currentUser?.uid ?? '';
    if (myUid.isNotEmpty && await _service.isUserInActiveGame(myUid)) {
      await ActiveRoomTracker.instance.clear(myUid);
      if (!mounted) return;
      if (await _service.isUserInActiveGame(myUid)) return;
    }
    if (!mounted) return;

    final fresh = _pendingInvites
        .where((i) => !_shown.contains(i.id) && !i.isExpired)
        .toList();
    if (fresh.isEmpty) {
      _showRetries = 0;
      return;
    }

    final dialogContext = _dialogContext;
    if (dialogContext == null) {
      if (_showRetries < _maxShowRetries) {
        _showRetries++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_maybeShowInvite());
        });
      }
      return;
    }
    _showRetries = 0;

    final invite = fresh.first;
    if (_shown.contains(invite.id)) return;
    _shown.add(invite.id);
    _dialogOpen = true;

    // dialogContext lấy từ _dialogContext (đã kiểm tra ctx.mounted) và dùng
    // ngay sau đó, không có async gap → an toàn.
    showDialog<void>(
      // ignore: use_build_context_synchronously
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
      if (mounted) {
        _dialogOpen = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_maybeShowInvite());
        });
      }
    });
  }

  Future<void> _acceptInvite(RoomInvite invite) async {
    setState(() => _joining = true);
    try {
      final myUid = AuthService().currentUser?.uid ?? '';
      if (myUid.isNotEmpty && await _service.isUserInActiveGame(myUid)) {
        final navContext = _dialogContext;
        if (navContext != null && navContext.mounted) {
          AppSnack.error(
            navContext,
            'Bạn đang chơi. Tham gia phòng khác sau khi ván kết thúc.',
          );
        }
        return;
      }

      try {
        await WaitingRoomSession.instance.leave();
      } catch (_) {}
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
    } catch (e) {
      if (kDebugMode) debugPrint('acceptInvite error: $e');
      final navContext = _dialogContext;
      if (navContext != null && navContext.mounted) {
        AppSnack.error(navContext, 'Không vào được phòng. Thử lại.');
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
