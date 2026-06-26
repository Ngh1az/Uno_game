import '../online/room.dart';

/// Chỉ chặn mời khi người được mời đang trong ván [RoomStatus.playing].
bool blocksRoomInviteForActiveRoom(String? roomStatus) =>
    roomStatus == RoomStatus.playing.name;
