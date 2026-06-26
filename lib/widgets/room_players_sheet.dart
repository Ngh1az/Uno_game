import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/uno_player.dart';
import '../online/room.dart';
import 'game/game_theme.dart';
import 'user_avatar.dart';

/// Danh sách người chơi trong phòng — xem trạng thái và đuổi (chủ phòng).
class RoomPlayersSheet extends StatelessWidget {
  const RoomPlayersSheet({
    super.key,
    required this.room,
    required this.myUid,
    required this.isHost,
    this.game,
    this.onKick,
  });

  final Room room;
  final String myUid;
  final bool isHost;
  final GameState? game;
  final Future<void> Function(String playerId, String playerName)? onKick;

  static Future<void> show(
    BuildContext context, {
    required Room room,
    required String myUid,
    required bool isHost,
    GameState? game,
    Future<void> Function(String playerId, String playerName)? onKick,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A0505),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RoomPlayersSheet(
        room: room,
        myUid: myUid,
        isHost: isHost,
        game: game,
        onKick: onKick,
      ),
    );
  }

  UnoPlayer? _gamePlayer(String id) {
    final g = game;
    if (g == null) return null;
    for (final p in g.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final inGame = game != null && room.status == RoomStatus.playing;
    final currentId = inGame ? game!.currentPlayer.id : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 14),
            const Text(
              'Người chơi trong phòng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${room.players.length}/${room.maxPlayers} người · Phòng ${room.code}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: room.players.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final rp = room.players[i];
                  final gp = _gamePlayer(rp.id);
                  final isMe = rp.id == myUid;
                  final isRoomHost = rp.id == room.hostId;
                  final isTurn = currentId == rp.id;
                  final strikes = gp == null ? 0 : game!.timeoutStrikeCount(rp.id);
                  final canKick = isHost && !isMe && onKick != null;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isTurn
                          ? const Color(0xCC2A1208)
                          : const Color(0xAA1A0505),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTurn
                            ? GameTheme.gold.withValues(alpha: 0.55)
                            : const Color(0x33FFFFFF),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          photoUrl: rp.photoUrl,
                          displayName: rp.name,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      rp.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isMe
                                            ? GameTheme.gold
                                            : Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(Bạn)',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _statusLine(
                                  isRoomHost: isRoomHost,
                                  isTurn: isTurn,
                                  inGame: inGame,
                                  handCount: gp?.hand.length,
                                  strikes: strikes,
                                ),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canKick)
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await onKick!(rp.id, rp.name);
                            },
                            icon: Icon(
                              Icons.person_remove_alt_1_rounded,
                              size: 18,
                              color: Colors.red.shade300,
                            ),
                            label: Text(
                              'Đuổi',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLine({
    required bool isRoomHost,
    required bool isTurn,
    required bool inGame,
    required int? handCount,
    required int strikes,
  }) {
    final parts = <String>[];
    if (isRoomHost) parts.add('Chủ phòng');
    if (inGame) {
      if (handCount != null) parts.add('$handCount lá');
      if (isTurn) parts.add('Đang lượt');
      if (strikes > 0) parts.add('Treo $strikes/3');
    } else {
      parts.add('Đang chờ');
    }
    return parts.join(' · ');
  }
}
