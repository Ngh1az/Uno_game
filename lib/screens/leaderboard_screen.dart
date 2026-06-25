import 'package:flutter/material.dart';

import '../online/auth_service.dart';
import '../ranking/leaderboard_entry.dart';
import '../ranking/leaderboard_service.dart';
import '../titles/title_definition.dart';
import '../widgets/game/title_mini_badge.dart';
import '../widgets/title_name_text.dart';
import '../widgets/uno_circle_button.dart';
import '../widgets/user_avatar.dart';

/// Bảng xếp hạng người chơi (xu, thắng online/offline).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD54F);

  final _service = LeaderboardService();
  late final TabController _tabs;

  final _cache = <LeaderboardMetric, List<LeaderboardEntry>>{};
  final _loading = <LeaderboardMetric, bool>{};
  final _errors = <LeaderboardMetric, String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: LeaderboardMetric.values.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load(LeaderboardMetric.values[_tabs.index]);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    _load(LeaderboardMetric.values[_tabs.index]);
  }

  Future<void> _load(LeaderboardMetric metric) async {
    if (_cache.containsKey(metric) || _loading[metric] == true) return;
    setState(() {
      _loading[metric] = true;
      _errors.remove(metric);
    });
    try {
      final rows = await _service.fetch(metric);
      if (!mounted) return;
      setState(() {
        _cache[metric] = rows;
        _loading[metric] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading[metric] = false;
        _errors[metric] = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('permission-denied')) {
      return 'Chưa có quyền xem bảng xếp hạng. Thử đăng nhập lại.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Mất kết nối. Kiểm tra internet rồi thử lại.';
    }
    return 'Không tải được bảng xếp hạng.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A0707),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.2,
            colors: [Color(0xFF4A1010), Color(0xFF1A0505), Color(0xFF2A0707)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              _tabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final metric in LeaderboardMetric.values)
                      _metricBody(metric),
                  ],
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
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
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
            name: 'XẾP HẠNG',
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

  Widget _tabBar() {
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      indicatorColor: _gold,
      labelColor: _gold,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      dividerColor: Colors.white12,
      tabs: [
        for (final metric in LeaderboardMetric.values)
          Tab(text: metric.label),
      ],
    );
  }

  Widget _metricBody(LeaderboardMetric metric) {
    if (_loading[metric] == true && !_cache.containsKey(metric)) {
      return const Center(
        child: CircularProgressIndicator(color: _gold),
      );
    }

    final error = _errors[metric];
    if (error != null) {
      return _errorState(error, () {
        _errors.remove(metric);
        _loading.remove(metric);
        _load(metric);
      });
    }

    final rows = _cache[metric] ?? const <LeaderboardEntry>[];
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu xếp hạng.\nChơi và đồng bộ tài khoản Google để lên bảng.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, height: 1.45),
        ),
      );
    }

    final myUid = AuthService().currentUser?.uid;
    return RefreshIndicator(
      color: _gold,
      backgroundColor: const Color(0xFF1A0505),
      onRefresh: () async {
        _cache.remove(metric);
        _loading.remove(metric);
        await _load(metric);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final row = rows[index];
          return _rankTile(
            rank: index + 1,
            entry: row,
            metric: metric,
            highlight: row.uid == myUid,
          );
        },
      ),
    );
  }

  Widget _errorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFAB40)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: _gold,
              ),
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankTile({
    required int rank,
    required LeaderboardEntry entry,
    required LeaderboardMetric metric,
    required bool highlight,
  }) {
    final title = entry.equippedTitleId == null
        ? null
        : titleById(entry.equippedTitleId!);
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD54F),
      2 => const Color(0xFFE0E0E0),
      3 => const Color(0xFFCD7F32),
      _ => Colors.white54,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? const Color(0xAA4A1010) : const Color(0x992A0707),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? _gold.withValues(alpha: 0.55)
              : _gold.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 42,
          child: Text(
            '#$rank',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.w900,
              fontSize: rank <= 3 ? 18 : 15,
            ),
          ),
        ),
        title: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    photoUrl: entry.photoUrl,
                    displayName: entry.displayName,
                    radius: 18,
                  ),
                  if (title != null) TitleCornerBadge(title: title),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlight ? Colors.white : Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          '${entry.value} ${metric.unit}',
          style: TextStyle(
            color: highlight ? _gold : Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
