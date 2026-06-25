import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../friends/friend_models.dart';
import '../friends/friends_service.dart';
import '../online/auth_service.dart';
import 'app_snack.dart';
import 'user_avatar.dart';

/// Danh sách bạn bè để mời vào phòng đang chờ.
class InviteFriendsSheet extends StatefulWidget {
  const InviteFriendsSheet({super.key, required this.roomCode});

  final String roomCode;

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
  }) {
    // Nạp cache trước / song song animation mở sheet.
    unawaited(FriendsService().warmFriendsCache());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A0505),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteFriendsSheet(roomCode: roomCode),
    );
  }

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  static const _gold = Color(0xFFFFD54F);

  final _service = FriendsService();
  String? _busyUid;

  Future<void> _inviteOnline(FriendProfile friend) async {
    setState(() => _busyUid = friend.uid);
    try {
      await _service.sendRoomInvite(
        toUid: friend.uid,
        roomCode: widget.roomCode,
        fromName: AuthService().displayName,
      );
      if (!mounted) return;
      AppSnack.info(context, 'Đã mời ${friend.displayName} vào phòng');
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
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _shareRoom({String? friendName}) async {
    final name = AuthService().displayName;
    final text =
        '$name mời bạn vào phòng UNO!\n'
        'Mã phòng: ${widget.roomCode}\n'
        'Mở app → Chơi online → nhập mã.';
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Mời chơi UNO'),
    );
    if (!mounted) return;
    if (friendName != null) {
      AppSnack.info(context, 'Đã chia sẻ mã cho $friendName');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.58;

    return SizedBox(
      height: sheetHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mời bạn bè',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mã phòng: ${widget.roomCode}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, letterSpacing: 2),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: BorderSide(color: _gold.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _shareRoom(),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text(
              'Chia sẻ mã phòng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Danh sách bạn bè',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<FriendProfile>>(
              stream: _service.watchFriends(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: _gold),
                    ),
                  );
                }
                final friends = snap.data!;
                if (friends.isEmpty) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'Chưa có bạn bè.\nThêm bạn ở màn Bạn bè trước.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  cacheExtent: 200,
                  itemCount: friends.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _friendTile(friends[i]),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _friendTile(FriendProfile friend) {
    final online = FriendsService.isFriendOnline(friend);
    final busy = _busyUid == friend.uid;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x992A0707),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: UserAvatar(
          photoUrl: friend.photoUrl,
          displayName: friend.displayName,
          radius: 22,
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? const Color(0xFF81C784) : Colors.white38,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                color: online ? const Color(0xFF81C784) : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
              )
            : online
                ? IconButton(
                    tooltip: 'Mời vào phòng',
                    onPressed: () => _inviteOnline(friend),
                    icon: const Icon(
                      Icons.sports_esports_rounded,
                      color: _gold,
                    ),
                  )
                : IconButton(
                    tooltip: 'Chia sẻ mã phòng',
                    onPressed: () => _shareRoom(friendName: friend.displayName),
                    icon: const Icon(Icons.share_rounded, color: _gold),
                  ),
      ),
    );
  }
}
