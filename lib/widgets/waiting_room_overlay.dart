import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/app_navigator.dart';
import '../online/waiting_room_session.dart';
import '../screens/online/room_screen.dart';
import 'app_snack.dart';
import 'game/game_theme.dart';

const _prefsKey = 'waiting_room_banner_pos_v1';

/// Overlay global: banner phòng chờ — kéo dọc cạnh trái/phải màn hình.
class WaitingRoomOverlay extends StatefulWidget {
  const WaitingRoomOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<WaitingRoomOverlay> createState() => _WaitingRoomOverlayState();
}

class _WaitingRoomOverlayState extends State<WaitingRoomOverlay> {
  final _session = WaitingRoomSession.instance;
  bool _expanded = false;
  bool _dockRight = true;
  double _topFraction = 0.35;
  bool _posLoaded = false;

  static const _collapsedW = 40.0;
  static const _collapsedH = 54.0;
  static const _expandedW = 152.0;
  static const _expandedH = 136.0;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _loadPosition();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final parts = raw.split(':');
      if (parts.length == 2) {
        _dockRight = parts[0] == 'right';
        _topFraction = double.tryParse(parts[1])?.clamp(0.0, 1.0) ?? 0.35;
      }
    }
    if (mounted) setState(() => _posLoaded = true);
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      '${_dockRight ? 'right' : 'left'}:$_topFraction',
    );
  }

  void _onSessionChanged() {
    if (!mounted) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      setState(() {});
      return;
    }

    if (_session.roomClosedWhileAway) {
      _session.clearRoomClosedFlag();
      setState(() => _expanded = false);
      AppSnack.info(ctx, 'Phòng đã đóng.');
      return;
    }

    if (_session.gameStartedWhileMinimized) {
      final code = _session.roomCode;
      _session.clearGameStartedFlag();
      setState(() => _expanded = false);
      AppSnack.info(
        ctx,
        'Ván đã bắt đầu — vào phòng ngay!',
        icon: Icons.sports_esports_rounded,
      );
      if (code != null) {
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => RoomScreen(code: code)),
        );
      }
    }

    setState(() {});
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  void _openRoom() {
    final code = _session.roomCode;
    final ctx = rootNavigatorKey.currentContext;
    if (code == null || ctx == null) return;
    setState(() => _expanded = false);
    _session.returnToRoomUi();
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => RoomScreen(code: code)),
    );
  }

  double _bannerTop(MediaQueryData mq) {
    final minTop = mq.padding.top + 8;
    final track = mq.size.height - mq.padding.bottom - minTop - _collapsedH - 8;
    final anchorTop = minTop + _topFraction * track;
    // Neo cố định — mở rộng chỉ kéo xuống; chỉ đẩy lên khi chạm đáy màn hình.
    final maxTop = mq.size.height - mq.padding.bottom - _expandedH - 8;
    return anchorTop.clamp(minTop, maxTop);
  }

  void _onDragUpdate(
    DragUpdateDetails details,
    double screenW,
    MediaQueryData mq,
  ) {
    final minTop = mq.padding.top + 8;
    final track = mq.size.height - mq.padding.bottom - minTop - _collapsedH - 8;
    if (track <= 0) return;

    setState(() {
      final currentTop = _bannerTop(mq);
      final newTop = (currentTop + details.delta.dy).clamp(minTop, minTop + track);
      _topFraction = (newTop - minTop) / track;
      _dockRight = details.globalPosition.dx >= screenW / 2;
    });
  }

  BoxDecoration _bannerDecoration() {
    return BoxDecoration(
      color: const Color(0xE61A0505),
      borderRadius: _dockRight
          ? const BorderRadius.horizontal(left: Radius.circular(14))
          : const BorderRadius.horizontal(right: Radius.circular(14)),
      border: Border.all(color: GameTheme.gold.withValues(alpha: 0.55)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 12,
          offset: Offset(_dockRight ? -2 : 2, 2),
        ),
      ],
    );
  }

  Widget _bannerShell(
    double width,
    double height,
    Widget child,
    MediaQueryData mq,
    double screenW,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: _bannerDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 10,
            child: _dragZone(mq, screenW),
          ),
        ],
      ),
    );
  }

  Widget _dragZone(MediaQueryData mq, double screenW) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (d) => _onDragUpdate(d, screenW, mq),
      onPanEnd: (_) => _savePosition(),
      child: const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            if (!_session.shouldShowFloatingBanner || !_posLoaded) {
              return const SizedBox.shrink();
            }

            final code = _session.roomCode ?? '------';
            final playerCount = _session.playerCount;
            final maxPlayers = _session.maxPlayers;
            final mq = MediaQuery.of(context);
            final screenW = mq.size.width;
            final top = _bannerTop(mq);

            return Positioned(
              top: top,
              left: _dockRight ? null : 0,
              right: _dockRight ? 0 : null,
              child: Material(
                color: Colors.transparent,
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  sizeCurve: Curves.easeOutCubic,
                  firstCurve: Curves.easeOutCubic,
                  secondCurve: Curves.easeInCubic,
                  alignment: _dockRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _bannerShell(
                    _collapsedW,
                    _collapsedH,
                    _collapsedBody(playerCount),
                    mq,
                    screenW,
                  ),
                  secondChild: _bannerShell(
                    _expandedW,
                    _expandedH,
                    _expandedBody(
                      code,
                      playerCount,
                      maxPlayers,
                    ),
                    mq,
                    screenW,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _collapsedBody(int playerCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleExpanded,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: GameTheme.gold.withValues(alpha: 0.95),
                  size: 18,
                ),
                Text(
                  '$playerCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTheme.gold.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedBody(
    String code,
    int playerCount,
    int maxPlayers,
  ) {
    final collapseIcon = _dockRight
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: GameTheme.gold.withValues(alpha: 0.95),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Đang chờ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _toggleExpanded,
                icon: Icon(
                  collapseIcon,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 18,
                ),
              ),
            ],
          ),
          Text(
            code,
            style: TextStyle(
              color: GameTheme.gold.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '$playerCount/$maxPlayers người',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: GameTheme.gold,
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openRoom,
            child: const Text(
              'Vào phòng',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
