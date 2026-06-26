import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../online/room.dart';
import '../../titles/title_definition.dart';
import '../../widgets/app_snack.dart';
import '../../widgets/game/game_theme.dart';
import '../../widgets/game/title_mini_badge.dart';
import '../../widgets/lobby_friend_button.dart';
import '../../widgets/title_name_text.dart';
import '../../widgets/uno_circle_button.dart';
import '../../widgets/user_avatar.dart';

/// Sảnh chờ phòng online — tách khỏi [RoomScreen] bàn chơi.
class WaitingRoomLobby extends StatelessWidget {
  const WaitingRoomLobby({
    super.key,
    required this.room,
    required this.myUid,
    required this.isHost,
    required this.onLeave,
    required this.onMinimizeHome,
    required this.onInviteFriends,
    required this.onStartGame,
  });

  final Room room;
  final String myUid;
  final bool isHost;
  final VoidCallback onLeave;
  final VoidCallback onMinimizeHome;
  final VoidCallback onInviteFriends;
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: UnoCircleButton(
                    icon: Icons.arrow_back,
                    label: '',
                    showLabel: false,
                    size: 38,
                    iconScale: 0.48,
                    onTap: onLeave,
                  ),
                ),
                const TitleNamePlain(
                  name: 'Phòng chờ',
                  tier: TitleTier.elite,
                  accent: GameTheme.gold,
                  fontSize: 22,
                  shimmer: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: UnoCircleButton(
                    icon: Icons.home_rounded,
                    label: '',
                    showLabel: false,
                    size: 38,
                    iconScale: 0.48,
                    onTap: onMinimizeHome,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Mã phòng', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              AppSnack.info(
                context,
                'Đã sao chép mã phòng',
                icon: Icons.content_copy_rounded,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GameTheme.gold.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: GameTheme.gold,
                side: BorderSide(color: GameTheme.gold.withValues(alpha: 0.45)),
              ),
              onPressed: onInviteFriends,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Mời bạn bè',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Người chơi (${room.players.length}/${room.maxPlayers})',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final p in room.players)
                  _LobbyPlayerTile(
                    player: p,
                    room: room,
                    myUid: myUid,
                  ),
              ],
            ),
          ),
          if (isHost)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: GameTheme.gold,
                ),
                onPressed: room.players.length >= 2 ? onStartGame : null,
                child: Text(
                  room.players.length >= 2
                      ? 'Bắt đầu'
                      : 'Cần ít nhất 2 người',
                ),
              ),
            )
          else
            const Text(
              'Đang chờ bắt đầu...',
              style: TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _LobbyPlayerTile extends StatelessWidget {
  const _LobbyPlayerTile({
    required this.player,
    required this.room,
    required this.myUid,
  });

  final RoomPlayer player;
  final Room room;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final isHost = player.id == room.hostId;
    final title = player.equippedTitleId == null
        ? null
        : titleById(player.equippedTitleId!);

    return Card(
      color: isHost ? const Color(0xCC2A1208) : const Color(0xAA1A0505),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: GameTheme.gold.withValues(alpha: isHost ? 0.62 : 0.25),
          width: isHost ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isHost ? 3 : 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GameTheme.gold.withValues(alpha: isHost ? 0.95 : 0.45),
                    width: isHost ? 2.2 : 1.5,
                  ),
                  boxShadow: isHost
                      ? [
                          BoxShadow(
                            color: GameTheme.gold.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: UserAvatar(
                  photoUrl: player.photoUrl,
                  displayName: player.name,
                  radius: 20,
                ),
              ),
              if (title != null) TitleCornerBadge(title: title),
            ],
          ),
        ),
        title: Text(
          player.name,
          style: TextStyle(
            color: isHost ? GameTheme.gold : Colors.white,
            fontWeight: isHost ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        trailing: player.id != myUid
            ? LobbyFriendButton(
                targetUid: player.id,
                targetName: player.name,
              )
            : null,
      ),
    );
  }
}
