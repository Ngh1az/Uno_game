import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'code_generator.dart';
import '../security/action_rate_limit.dart';
import 'friend_models.dart';
import 'presence_service.dart';

class FriendsException implements Exception {
  FriendsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Quản lý bạn bè, lời mời kết bạn và mời vào phòng.
class FriendsService {
  FriendsService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _friendCodes =>
      _db.collection('friend_codes');

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _db.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');

  CollectionReference<Map<String, dynamic>> _roomInvites(String toUid) =>
      _users.doc(toUid).collection('room_invites');

  List<FriendProfile>? _friendsCache;

  /// Nạp cache danh sách bạn bè (gọi sớm ở phòng chờ để mở sheet mượt hơn).
  Future<void> warmFriendsCache() async {
    if (uid.isEmpty) return;
    try {
      final snap = await _friendships
          .where('members', arrayContains: uid)
          .get();
      _friendsCache = await _friendsFromSnapshot(snap);
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsService.warmFriendsCache: $e');
    }
  }

  /// Đảm bảo user có friendCode (gọi từ CloudProgressService.sync / FriendsScreen).
  Future<String> ensureFriendCode(String userId) async {
    final ref = _users.doc(userId);
    final snap = await ref.get();
    final existing = snap.data()?['friendCode'] as String?;
    if (existing != null && existing.length == 6) {
      await _backfillFriendCodeMapping(existing, userId);
      return existing;
    }

    final code = await generateUniqueFirestoreCode(_friendCodes);
    await _db.runTransaction((tx) async {
      final codeSnap = await tx.get(_friendCodes.doc(code));
      if (codeSnap.exists) throw FriendsException('Mã trùng, thử lại.');
      tx.set(_friendCodes.doc(code), {'uid': userId});
      tx.set(ref, {'friendCode': code}, SetOptions(merge: true));
    });
    return code;
  }

  Future<void> _backfillFriendCodeMapping(String code, String userId) async {
    if (uid.isEmpty || uid != userId) return;
    try {
      final codeRef = _friendCodes.doc(code);
      final codeSnap = await codeRef.get();
      if (!codeSnap.exists) {
        await codeRef.set({'uid': userId});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsService._backfillFriendCodeMapping: $e');
    }
  }

  /// Tra cứu uid từ mã — friend_codes trước, users.friendCode dự phòng.
  Future<String?> _resolveUidFromFriendCode(String code) async {
    final codeSnap = await _friendCodes.doc(code).get();
    if (codeSnap.exists) {
      final uid = codeSnap.data()?['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return uid;
    }

    final users = await _users
        .where('friendCode', isEqualTo: code)
        .limit(1)
        .get();
    if (users.docs.isEmpty) return null;

    final uid = users.docs.first.id;
    return uid;
  }

  Future<String?> getMyFriendCode() async {
    if (uid.isEmpty) return null;
    final snap = await _users.doc(uid).get();
    return snap.data()?['friendCode'] as String?;
  }

  Stream<String?> watchMyFriendCode() {
    if (uid.isEmpty) return Stream.value(null);
    return _users.doc(uid).snapshots().map(
          (s) => s.data()?['friendCode'] as String?,
        );
  }

  /// Gửi lời mời kết bạn bằng mã.
  Future<void> sendFriendRequestByCode(String code) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.length != 6) {
      throw FriendsException('Mã bạn bè phải 6 ký tự.');
    }

    final targetUid = await _resolveUidFromFriendCode(normalized);
    if (targetUid == null || targetUid.isEmpty) {
      throw FriendsException('Không tìm thấy mã bạn bè "$normalized".');
    }

    await sendFriendRequestToUid(targetUid);
  }

  /// Gửi lời mời kết bạn trực tiếp theo uid (phòng chờ, v.v.).
  Future<void> sendFriendRequestToUid(String targetUid) async {
    final myUid = uid;
    if (myUid.isEmpty) throw FriendsException('Cần đăng nhập.');

    final limited = ActionRateLimit.forUid(
      'friend_request',
      myUid,
      limit: 15,
      window: const Duration(hours: 1),
    );
    if (limited != null) throw FriendsException(limited);

    if (targetUid.isEmpty) {
      throw FriendsException('Người chơi không hợp lệ.');
    }
    if (targetUid == myUid) {
      throw FriendsException('Không thể kết bạn với chính mình.');
    }

    if (await _areFriends(myUid, targetUid)) {
      throw FriendsException('Hai bạn đã là bạn bè.');
    }

    try {
      final existing = await _friendRequests
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw FriendsException('Đã gửi lời mời, đang chờ phản hồi.');
      }

      final reverse = await _friendRequests
          .where('fromUid', isEqualTo: targetUid)
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (reverse.docs.isNotEmpty) {
        throw FriendsException('Người này đã gửi lời mời — hãy chấp nhận.');
      }
    } on FirebaseException catch (e) {
      throw FriendsException(_mapFirebaseError(e));
    }

    final mySnap = await _users.doc(myUid).get();
    final myData = mySnap.data() ?? {};
    try {
      await _friendRequests.add({
        'fromUid': myUid,
        'toUid': targetUid,
        'status': 'pending',
        'fromName': myData['displayName'] ?? 'Người chơi',
        'fromPhotoUrl': myData['photoUrl'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw FriendsException(_mapFirebaseError(e));
    }
  }

  /// Theo dõi quan hệ bạn bè với một uid (realtime cho phòng chờ).
  Stream<FriendLinkState> watchLinkWith(String otherUid) {
    final myUid = uid;
    if (myUid.isEmpty) return Stream.value(const FriendLinkState.none());
    if (otherUid.isEmpty || otherUid == myUid) {
      return Stream.value(const FriendLinkState.self());
    }

    final friendshipId = friendshipIdFor(myUid, otherUid);
    final controller = StreamController<FriendLinkState>();

    var isFriend = false;
    QuerySnapshot<Map<String, dynamic>>? sentSnap;
    QuerySnapshot<Map<String, dynamic>>? recvSnap;

    void publish() {
      if (controller.isClosed) return;
      if (isFriend) {
        controller.add(const FriendLinkState.friends());
        return;
      }
      final recvDocs = recvSnap?.docs ?? [];
      if (recvDocs.isNotEmpty) {
        controller.add(FriendLinkState.received(recvDocs.first.id));
        return;
      }
      final sentDocs = sentSnap?.docs ?? [];
      if (sentDocs.isNotEmpty) {
        controller.add(const FriendLinkState.sent());
        return;
      }
      controller.add(const FriendLinkState.none());
    }

    final subs = <StreamSubscription<dynamic>>[
      _friendships.doc(friendshipId).snapshots().listen((snap) {
        isFriend = snap.exists;
        publish();
      }),
      _friendRequests
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: otherUid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        sentSnap = snap;
        publish();
      }),
      _friendRequests
          .where('fromUid', isEqualTo: otherUid)
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        recvSnap = snap;
        publish();
      }),
    ];

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  static String mapFirebaseError(FirebaseException e) => _mapFirebaseError(e);

  static String _mapFirebaseError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Không có quyền. Hãy đăng nhập Google và thử lại.';
    }
    if (e.code == 'failed-precondition') {
      return 'Hệ thống đang cập nhật index. Thử lại sau vài phút.';
    }
    if (e.code == 'unavailable') {
      return 'Mất kết nối Firestore. Kiểm tra mạng.';
    }
    return e.message ?? 'Lỗi Firestore (${e.code}).';
  }

  Future<bool> _areFriends(String a, String b) async {
    final id = friendshipIdFor(a, b);
    final snap = await _friendships.doc(id).get();
    return snap.exists;
  }

  Stream<List<FriendRequest>> watchIncomingRequests() {
    if (uid.isEmpty) return Stream.value(const []);
    return _friendRequests
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(_requestFromDoc).toList());
  }

  FriendRequest _requestFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return FriendRequest(
      id: doc.id,
      fromUid: data['fromUid'] as String,
      toUid: data['toUid'] as String,
      status: data['status'] as String? ?? 'pending',
      fromName: data['fromName'] as String?,
      fromPhotoUrl: data['fromPhotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final myUid = uid;
    if (myUid.isEmpty) throw FriendsException('Cần đăng nhập.');

    final reqRef = _friendRequests.doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) throw FriendsException('Lời mời không tồn tại.');

    final data = reqSnap.data()!;
    final toUid = data['toUid'] as String;
    final fromUid = data['fromUid'] as String;
    if (toUid != myUid) throw FriendsException('Không có quyền.');

    final friendshipId = friendshipIdFor(fromUid, toUid);
    try {
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(reqRef);
        if (!fresh.exists || fresh.data()?['status'] != 'pending') {
          throw FriendsException('Lời mời đã xử lý.');
        }
        tx.update(reqRef, {'status': 'accepted'});
        tx.set(_friendships.doc(friendshipId), {
          'members': [fromUid, toUid],
          'sourceRequestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw FriendsException(_mapFirebaseError(e));
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    final myUid = uid;
    final reqRef = _friendRequests.doc(requestId);
    final snap = await reqRef.get();
    if (!snap.exists) return;
    if (snap.data()?['toUid'] != myUid) {
      throw FriendsException('Không có quyền.');
    }
    try {
      await reqRef.update({'status': 'declined'});
    } on FirebaseException catch (e) {
      throw FriendsException(_mapFirebaseError(e));
    }
  }

  Stream<List<FriendProfile>> watchFriends() {
    if (uid.isEmpty) return Stream.value(const []);

    return Stream.multi((controller) {
      final profileSubs =
          <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
      final profiles = <String, FriendProfile>{};
      var currentUids = <String>[];

      void emitSorted() {
        final friends = currentUids
            .map((id) => profiles[id])
            .whereType<FriendProfile>()
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _friendsCache = friends;
        if (!controller.isClosed) controller.add(friends);
      }

      void syncProfileListeners(List<String> uids) {
        final target = uids.toSet();
        for (final id in profileSubs.keys.toList()) {
          if (!target.contains(id)) {
            profileSubs.remove(id)?.cancel();
            profiles.remove(id);
          }
        }
        for (final id in uids) {
          if (profileSubs.containsKey(id)) continue;
          profileSubs[id] = _users.doc(id).snapshots().listen(
            (snap) {
              if (!snap.exists) {
                profiles.remove(id);
              } else {
                profiles[id] = _profileFromData(id, snap.data()!);
              }
              emitSorted();
            },
            onError: controller.addError,
          );
        }
        emitSorted();
      }

      final cached = _friendsCache;
      if (cached != null) {
        controller.add(cached);
      }

      final friendshipSub = _friendships
          .where('members', arrayContains: uid)
          .snapshots()
          .listen(
            (snap) {
              currentUids = _friendUidsFromSnapshot(snap);
              syncProfileListeners(currentUids);
            },
            onError: controller.addError,
          );

      // Cập nhật khi hết hạn ngưỡng online theo lastActiveAt (không cần sự kiện Firestore).
      final tickTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => emitSorted(),
      );

      controller.onCancel = () {
        friendshipSub.cancel();
        tickTimer.cancel();
        for (final sub in profileSubs.values) {
          sub.cancel();
        }
      };
    });
  }

  List<String> _friendUidsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final myUid = uid;
    final uids = <String>[];
    for (final doc in snap.docs) {
      final members = (doc.data()['members'] as List).cast<String>();
      final otherUid = members.firstWhere((m) => m != myUid, orElse: () => '');
      if (otherUid.isNotEmpty) uids.add(otherUid);
    }
    return uids;
  }

  Future<List<FriendProfile>> _friendsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final uids = _friendUidsFromSnapshot(snap);
    if (uids.isEmpty) return const [];

    final loaded = await Future.wait(uids.map(_loadProfile));
    final friends = loaded.whereType<FriendProfile>().toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return friends;
  }

  FriendProfile _profileFromData(String friendUid, Map<String, dynamic> data) {
    final name = (data['displayName'] as String?)?.trim();
    return FriendProfile(
      uid: friendUid,
      displayName: (name != null && name.isNotEmpty) ? name : 'Người chơi',
      photoUrl: data['photoUrl'] as String?,
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      onlineFlag: data['isOnline'] as bool?,
    );
  }

  Future<FriendProfile?> _loadProfile(String friendUid) async {
    final snap = await _users.doc(friendUid).get();
    if (!snap.exists) return null;
    return _profileFromData(friendUid, snap.data()!);
  }

  /// Mời bạn online vào phòng đang chờ.
  Future<void> sendRoomInvite({
    required String toUid,
    required String roomCode,
    required String fromName,
  }) async {
    final myUid = uid;
    if (myUid.isEmpty) throw FriendsException('Cần đăng nhập.');

    final limited = ActionRateLimit.forUid(
      'room_invite:$toUid',
      myUid,
      limit: 5,
      window: const Duration(minutes: 10),
    );
    if (limited != null) throw FriendsException(limited);

    final roomSnap = await _db.collection('rooms').doc(roomCode).get();
    if (!roomSnap.exists) {
      throw FriendsException('Phòng không tồn tại.');
    }
    final room = roomSnap.data()!;
    if (room['status'] != 'waiting') {
      throw FriendsException('Phòng đã bắt đầu chơi.');
    }
    final playerIds = (room['playerIds'] as List?)?.cast<String>() ?? [];
    if (!playerIds.contains(myUid)) {
      throw FriendsException('Bạn không ở trong phòng này.');
    }

    if (!await _areFriends(myUid, toUid)) {
      throw FriendsException('Chỉ mời được bạn bè.');
    }

    final expiresAt = DateTime.now().add(const Duration(minutes: 30));
    await _roomInvites(toUid).add({
      'fromUid': myUid,
      'fromName': fromName,
      'roomCode': roomCode,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
  }

  Stream<List<RoomInvite>> watchRoomInvites() {
    if (uid.isEmpty) return Stream.value(const []);
    return _roomInvites(uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) {
            final data = doc.data();
            return RoomInvite(
              id: doc.id,
              fromUid: data['fromUid'] as String,
              fromName: data['fromName'] as String? ?? 'Người chơi',
              roomCode: data['roomCode'] as String,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
            );
          })
          .where((i) => !i.isExpired)
          .toList();
    });
  }

  Future<void> dismissRoomInvite(String inviteId) async {
    if (uid.isEmpty) return;
    await _roomInvites(uid).doc(inviteId).delete();
  }

  static bool isFriendOnline(FriendProfile friend) =>
      PresenceService.isOnline(
        friend.lastActiveAt,
        onlineFlag: friend.onlineFlag,
      );
}
