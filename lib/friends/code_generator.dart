import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sinh mã 6 ký tự chưa tồn tại trong collection Firestore.
Future<String> generateUniqueFirestoreCode(
  CollectionReference<Map<String, dynamic>> collection,
) async {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  for (var attempt = 0; attempt < 10; attempt++) {
    final code = List.generate(
      6,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    final snap = await collection.doc(code).get();
    if (!snap.exists) return code;
  }
  throw StateError('Không tạo được mã, thử lại.');
}

String friendshipIdFor(String uidA, String uidB) {
  final sorted = [uidA, uidB]..sort();
  return '${sorted[0]}_${sorted[1]}';
}
