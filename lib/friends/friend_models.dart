/// Hồ sơ bạn bè hiển thị trên danh sách.
class FriendProfile {
  const FriendProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.lastActiveAt,
    this.onlineFlag,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final DateTime? lastActiveAt;
  /// `false` khi user đã thoát app / đánh dấu offline.
  final bool? onlineFlag;

  bool get isOnline {
    final flag = onlineFlag;
    if (flag == false) return false;
    final at = lastActiveAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 2);
  }
}

/// Lời mời kết bạn đang chờ.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    this.fromName,
    this.fromPhotoUrl,
    this.createdAt,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String status;
  final String? fromName;
  final String? fromPhotoUrl;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
}

/// Trạng thái quan hệ với một người chơi (phòng chờ / lobby).
enum FriendLinkKind { self, none, friends, sent, received }

class FriendLinkState {
  const FriendLinkState._(this.kind, {this.requestId});

  const FriendLinkState.self() : this._(FriendLinkKind.self);
  const FriendLinkState.none() : this._(FriendLinkKind.none);
  const FriendLinkState.friends() : this._(FriendLinkKind.friends);
  const FriendLinkState.sent() : this._(FriendLinkKind.sent);
  const FriendLinkState.received(String requestId)
      : this._(FriendLinkKind.received, requestId: requestId);

  final FriendLinkKind kind;
  final String? requestId;
}

/// Lời mời vào phòng online.
class RoomInvite {
  const RoomInvite({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.roomCode,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String roomCode;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }
}
