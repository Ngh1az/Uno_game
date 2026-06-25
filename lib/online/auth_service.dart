import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_auth_config.dart';
import '../security/action_rate_limit.dart';
import '../user/user_session.dart';
import '../friends/presence_service.dart';
import 'guest_session_store.dart';

/// Quản lý đăng nhập: Google (GIS) hoặc khách (ẩn danh).
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Tên hiển thị: tên Google nếu có, ngược lại "Khách".
  String get displayName {
    final u = _auth.currentUser;
    if (u == null) return 'Khách';
    final name = u.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return u.isAnonymous ? 'Khách' : 'Người chơi';
  }

  bool get isGuest => _auth.currentUser?.isAnonymous ?? true;

  /// Ảnh đại diện từ Google (hoặc null nếu khách / chưa có).
  String? get photoUrl {
    final url = _auth.currentUser?.photoURL;
    if (url == null || url.trim().isEmpty) return null;
    return url.trim();
  }

  /// Email đăng nhập (Google), null nếu khách.
  String? get email {
    final value = _auth.currentUser?.email;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim().toLowerCase();
  }

  /// Khởi động auth: khôi phục phiên Google hoặc khách đã lưu trên máy.
  static Future<void> bootstrap() async {
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }

    await initGoogleSignIn();
    await FirebaseAuth.instance.authStateChanges().first;

    var user = FirebaseAuth.instance.currentUser;
    if (user?.isAnonymous ?? false) {
      await _restoreGuestProfile(user!);
    } else if (kIsWeb && user == null) {
      try {
        final restored =
            await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (restored != null) {
          await _signInToFirebase(restored);
        }
      } on GoogleSignInException catch (e) {
        if (kDebugMode) {
          debugPrint('GIS silent sign-in skipped: ${e.code}');
        }
      }
      user = FirebaseAuth.instance.currentUser;
    }
  }

  static Future<void> _restoreGuestProfile(User user) async {
    final storedName = await GuestSessionStore.readDisplayName();
    final firebaseName = user.displayName?.trim();
    if ((firebaseName == null || firebaseName.isEmpty) &&
        storedName != null &&
        storedName.isNotEmpty) {
      await user.updateDisplayName(storedName);
      await user.reload();
    }
    await GuestSessionStore.save(
      uid: user.uid,
      displayName: user.displayName ?? storedName,
    );
  }

  /// Khởi tạo Google Identity Services (gọi một lần khi app start).
  static Future<void> initGoogleSignIn() async {
    if (_googleInitialized) return;

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: kIsWeb ? kGoogleWebClientId : null,
      serverClientId: kIsWeb ? null : kGoogleWebClientId,
    );

    googleSignIn.authenticationEvents.listen(
      (event) async {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          await _signInToFirebase(event.user);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('Google Sign-In error: $error');
        }
      },
    );

    _googleInitialized = true;
  }

  static Future<void> _signInToFirebase(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google không trả về idToken. Thêm SHA-1 debug vào Firebase rồi tải lại google-services.json.',
      );
    }

    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null && !current.isAnonymous) return;

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    if (current != null && current.isAnonymous) {
      await UserSession.rememberGuestProgressUid(current.uid);
    } else {
      final storedGuestUid = await GuestSessionStore.readUid();
      if (storedGuestUid != null) {
        await UserSession.rememberGuestProgressUid(storedGuestUid);
      }
    }

    await UserSession.deactivate();
    await GuestSessionStore.clear();

    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          await auth.signOut();
          await auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
      }
    } else {
      await auth.signInWithCredential(credential);
    }
    await auth.currentUser?.reload();
  }

  /// Đăng nhập khách — phiên Firebase + backup local, giữ khi mở lại app.
  Future<void> signInAsGuest() async {
    final limited = await ActionRateLimit.tryGuestSignIn();
    if (limited != null) throw StateError(limited);

    await _auth.signInAnonymously();
    final user = _auth.currentUser;
    if (user != null) {
      await GuestSessionStore.save(
        uid: user.uid,
        displayName: user.displayName,
      );
    }
  }

  /// Đăng nhập Google qua GIS (`authenticate` trên mobile).
  ///
  /// Trên web, dùng [GoogleSignInButton] (GIS `renderButton`) thay vì gọi hàm này.
  Future<void> signInWithGoogle() async {
    await initGoogleSignIn();

    if (kIsWeb) {
      throw UnsupportedError(
        'Trên web hãy dùng nút Google Identity Services (renderButton).',
      );
    }

    final account = await GoogleSignIn.instance.authenticate();
    await _signInToFirebase(account);
  }

  /// Đăng xuất — xóa phiên Firebase/Google và dữ liệu khách trên máy.
  Future<void> signOut() async {
    await PresenceService.instance.goOffline();
    await UserSession.deactivate();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        await GoogleSignIn.instance.signOut();
      }
    }
    await GuestSessionStore.clear();
    await _auth.signOut();
  }

  /// Cập nhật tên hiển thị (áp dụng cho khách và tài khoản Google).
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    await user.updateDisplayName(trimmed);
    await user.reload();
    if (user.isAnonymous) {
      await GuestSessionStore.save(uid: user.uid, displayName: trimmed);
    }
  }
}
