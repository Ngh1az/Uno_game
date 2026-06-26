import 'package:flutter/material.dart';

import '../../daily_quests/daily_quest_store.dart';
import '../../titles/title_definition.dart';
import '../../titles/title_store.dart';
import '../../friends/active_room_tracker.dart';
import '../../friends/friends_service.dart';
import '../../online/auth_service.dart';
import '../../online/room_service.dart';
import '../../online/waiting_room_session.dart';
import '../../widgets/title_name_text.dart';
import '../../widgets/uno_circle_button.dart';
import 'room_screen.dart';

/// Màn chơi online: tạo phòng hoặc vào bằng mã.
class OnlineMenuScreen extends StatefulWidget {
  const OnlineMenuScreen({super.key});

  @override
  State<OnlineMenuScreen> createState() => _OnlineMenuScreenState();
}

class _OnlineMenuScreenState extends State<OnlineMenuScreen> {
  static const _gold = Color(0xFFFFD54F);
  static const _onlineBlue = Color(0xFF1565C0);

  final _service = RoomService();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  String get _name => AuthService().displayName;

  RoomPlayerProfile get _profile => RoomPlayerProfile(
        photoUrl: AuthService().photoUrl,
        equippedTitleId: TitleStore.instance.equippedId,
      );

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final myUid = _service.uid;
      if (myUid.isNotEmpty &&
          await FriendsService().isUserInActiveGame(myUid)) {
        // Dọn stale tracker nếu phòng cũ đã không còn user.
        await ActiveRoomTracker.instance.clear(myUid);
        if (await FriendsService().isUserInActiveGame(myUid)) {
          throw RoomException(
            'Bạn đang chơi ván. Rời ván hoặc chờ kết thúc trước khi vào phòng khác.',
          );
        }
      }
      final code = await action();
      if (!mounted) return;
      DailyQuestStore.instance.markOnlineJoin();
      TitleStore.instance.recordOnlineJoin();
      WaitingRoomSession.instance.bind(code);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomScreen(code: code)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _createRoom() =>
      _run(() => _service.createRoom(hostName: _name, profile: _profile));

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('permission-denied')) {
      return 'Không có quyền truy cập Firestore. Hãy đăng nhập lại hoặc liên hệ admin.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Mất kết nối mạng. Kiểm tra internet rồi thử lại.';
    }
    if (e is RoomException) return e.message;
    return text.replaceFirst('Exception: ', '');
  }

  void _joinRoom() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Nhập mã phòng');
      return;
    }
    _run(() async {
      await _service.joinRoom(code: code, name: _name, profile: _profile);
      return code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF2A0707),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.2,
            colors: [Color(0xFF1A3A6A), Color(0xFF1A0505), Color(0xFF2A0707)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Align(
                  alignment: Alignment(0, -0.15),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _mainCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: UnoCircleButton(
              icon: Icons.arrow_back,
              label: '',
              showLabel: false,
              size: 44,
              iconScale: 0.52,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const TitleNamePlain(
            name: 'CHƠI ONLINE',
            tier: TitleTier.elite,
            accent: _gold,
            fontSize: 20,
            letterSpacing: 1.2,
            shimmer: true,
          ),
        ],
      ),
    );
  }

  Widget _mainCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x662A0707),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Xin chào, $_name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tạo phòng mới hoặc nhập mã để chơi cùng bạn bè',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _actionButton(
              label: 'Tạo phòng mới',
              icon: Icons.add_circle_outline_rounded,
              color: _onlineBlue,
              onTap: _createRoom,
            ),
            const SizedBox(height: 24),
            _orDivider(),
            const SizedBox(height: 24),
            const Text(
              'Vào phòng bằng mã',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                letterSpacing: 6,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration(
                hintText: 'MÃ PHÒNG',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: 'Vào phòng',
              icon: Icons.login_rounded,
              color: const Color(0xFFD32F2F),
              onTap: _joinRoom,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x33FF6F00),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFAB40).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: _goldLine()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'HOẶC',
            style: TextStyle(
              color: _gold.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(child: _goldLine()),
      ],
    );
  }

  Widget _goldLine() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _gold.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
