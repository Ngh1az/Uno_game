import 'package:flutter/material.dart';

import '../../daily_quests/daily_quest_store.dart';
import '../../titles/title_store.dart';
import '../../online/auth_service.dart';
import '../../online/room_service.dart';
import '../../widgets/uno_circle_button.dart';
import 'room_screen.dart';

/// Màn chơi online: tạo phòng hoặc vào bằng mã.
class OnlineMenuScreen extends StatefulWidget {
  const OnlineMenuScreen({super.key});

  @override
  State<OnlineMenuScreen> createState() => _OnlineMenuScreenState();
}

class _OnlineMenuScreenState extends State<OnlineMenuScreen> {
  final _service = RoomService();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  String get _name => AuthService().displayName;

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
      final code = await action();
      if (!mounted) return;
      DailyQuestStore.instance.markOnlineJoin();
      TitleStore.instance.recordOnlineJoin();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomScreen(code: code)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _createRoom() => _run(() => _service.createRoom(hostName: _name));

  void _joinRoom() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Nhập mã phòng');
      return;
    }
    _run(() async {
      await _service.joinRoom(code: code, name: _name);
      return code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A0707),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF1565C0), Color(0xFF0D3311), Color(0xFF2A0707)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                Text(
                  'Xin chào, $_name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _busy ? null : _createRoom,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Tạo phòng mới',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('hoặc', style: TextStyle(color: Colors.white54)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  decoration: InputDecoration(
                    hintText: 'MÃ PHÒNG',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 4,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC400),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _busy ? null : _joinRoom,
                    child: const Text(
                      'Vào phòng',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFFAB40)),
                  ),
                ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          UnoCircleButton(
            icon: Icons.arrow_back,
            label: '',
            showLabel: false,
            size: 44,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Chơi online',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
