import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/friends/room_invite_policy.dart';
import 'package:uno_game/online/room.dart';

void main() {
  test('playing chặn mời', () {
    expect(
      blocksRoomInviteForActiveRoom(RoomStatus.playing.name),
      isTrue,
    );
  });

  test('waiting cho phép mời', () {
    expect(
      blocksRoomInviteForActiveRoom(RoomStatus.waiting.name),
      isFalse,
    );
  });

  test('finished cho phép mời', () {
    expect(
      blocksRoomInviteForActiveRoom(RoomStatus.finished.name),
      isFalse,
    );
  });

  test('không có phòng cho phép mời', () {
    expect(blocksRoomInviteForActiveRoom(null), isFalse);
    expect(blocksRoomInviteForActiveRoom(''), isFalse);
  });
}
