import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../friends/friend_models.dart';
import '../friends/friends_service.dart';
import '../online/auth_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/game/game_theme.dart';
import '../widgets/google_account_gate.dart';

/// Nút kết bạn trên dòng người chơi trong phòng chờ.
class LobbyFriendButton extends StatefulWidget {
  const LobbyFriendButton({
    super.key,
    required this.targetUid,
    required this.targetName,
  });

  final String targetUid;
  final String targetName;

  @override
  State<LobbyFriendButton> createState() => _LobbyFriendButtonState();
}

class _LobbyFriendButtonState extends State<LobbyFriendButton> {
  final _service = FriendsService();
  bool _busy = false;

  Future<void> _sendRequest() async {
    if (!await requireGoogleAccount(context)) return;
    setState(() => _busy = true);
    try {
      await _service.sendFriendRequestToUid(widget.targetUid);
      if (!mounted) return;
      AppSnack.info(context, 'Đã gửi lời mời tới ${widget.targetName}');
    } on FriendsException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          e is FirebaseException
              ? FriendsService.mapFirebaseError(e)
              : 'Không gửi được lời mời.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    setState(() => _busy = true);
    try {
      await _service.acceptFriendRequest(requestId);
      if (!mounted) return;
      AppSnack.info(context, 'Đã kết bạn với ${widget.targetName}');
    } on FriendsException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          e is FirebaseException
              ? FriendsService.mapFirebaseError(e)
              : 'Không chấp nhận được lời mời.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().isGuest) return const SizedBox.shrink();

    return StreamBuilder<FriendLinkState>(
      stream: _service.watchLinkWith(widget.targetUid),
      builder: (context, snap) {
        final link = snap.data;
        if (link == null || link.kind == FriendLinkKind.self) {
          return const SizedBox.shrink();
        }

        if (_busy) {
          return const SizedBox(
            width: 36,
            height: 36,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GameTheme.gold,
              ),
            ),
          );
        }

        return switch (link.kind) {
          FriendLinkKind.friends => const SizedBox.shrink(),
          FriendLinkKind.sent => const _StatusChip(
              label: 'Đã gửi',
              icon: Icons.schedule_rounded,
              color: Colors.white54,
            ),
          FriendLinkKind.received => IconButton(
              tooltip: 'Chấp nhận kết bạn',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: link.requestId == null
                  ? null
                  : () => _acceptRequest(link.requestId!),
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF81C784),
                size: 24,
              ),
            ),
          FriendLinkKind.none => IconButton(
              tooltip: 'Kết bạn',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _sendRequest,
              icon: const Icon(
                Icons.person_add_outlined,
                color: GameTheme.gold,
                size: 22,
              ),
            ),
          FriendLinkKind.self => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
