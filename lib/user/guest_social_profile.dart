import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../friends/friends_service.dart';

/// Hồ sơ xã hội tối thiểu trên Firestore cho tài khoản khách (mã bạn bè + tên).
abstract final class GuestSocialProfile {
  static const _collection = 'users';

  /// Ghi `displayName` lên `users/{uid}` và đảm bảo có mã bạn bè.
  static Future<void> ensure({
    required String uid,
    String? displayName,
  }) async {
    if (uid.isEmpty) return;

    final name = displayName?.trim();
    try {
      final ref = FirebaseFirestore.instance.collection(_collection).doc(uid);
      if (name != null && name.isNotEmpty) {
        await ref.set(
          {
            'displayName': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await FriendsService().ensureFriendCode(uid);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('GuestSocialProfile.ensure failed: $e\n$stack');
      }
    }
  }

  /// Cập nhật tên hiển thị khi khách đổi tên trong app.
  static Future<void> updateDisplayName(String uid, String name) async {
    if (uid.isEmpty) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection(_collection).doc(uid).set(
        {
          'displayName': trimmed,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('GuestSocialProfile.updateDisplayName failed: $e\n$stack');
      }
    }
  }
}
