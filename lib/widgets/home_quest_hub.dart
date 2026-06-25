import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../daily_quests/daily_quest.dart';
import '../daily_quests/daily_quest_store.dart';
import 'app_snack.dart';
import 'home_layout.dart';
import 'home_play_menu.dart';

/// Khu nhiệm vụ (ngày + tuần) và nút chơi — mở/thu bằng mũi tên trên header.
class HomeQuestHub extends StatefulWidget {
  const HomeQuestHub({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    required this.onLeaderboard,
    required this.onFriends,
  });

  final VoidCallback onPlayOffline;
  final VoidCallback onPlayOnline;
  final VoidCallback onLeaderboard;
  final VoidCallback onFriends;

  @override
  State<HomeQuestHub> createState() => _HomeQuestHubState();
}

class _HomeQuestHubState extends State<HomeQuestHub> {
  static const _gold = Color(0xFFFFD54F);

  bool _dailyExpanded = true;
  bool _weeklyExpanded = false;

  bool get _bothCollapsed => !_dailyExpanded && !_weeklyExpanded;

  int _maxVisibleRows(_HubMetrics metrics, bool bothOpen, int questCount) {
    final cap = !bothOpen
        ? (metrics.compact ? 3 : 4)
        : metrics.useSideBySide
            ? 5
            : metrics.maxHeight < 360
                ? 1
                : 2;
    return math.min(cap, math.max(questCount, 1));
  }

  double _maxQuestScrollHeight(_HubMetrics metrics, bool bothOpen) {
    if (metrics.useSideBySide) return metrics.maxHeight;
    if (bothOpen) return metrics.maxHeight * 0.38;
    return double.infinity;
  }

  void _toggleDaily(_HubMetrics metrics) {
    setState(() {
      final opening = !_dailyExpanded;
      _dailyExpanded = opening;
      if (opening && metrics.singlePanelMode) _weeklyExpanded = false;
    });
  }

  void _toggleWeekly(_HubMetrics metrics) {
    setState(() {
      final opening = !_weeklyExpanded;
      _weeklyExpanded = opening;
      if (opening && metrics.singlePanelMode) _dailyExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = DailyQuestStore.instance;

    return Padding(
      padding: HomeLayout.contentPadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: HomeLayout.maxContentWidth(context),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _HubMetrics.from(constraints);

              final gap = metrics.compact ? 6.0 : 8.0;
              final bothOpen = _dailyExpanded && _weeklyExpanded;
              final dailyMaxRows =
                  _maxVisibleRows(metrics, bothOpen, store.dailyQuests.length);
              final weeklyMaxRows =
                  _maxVisibleRows(metrics, bothOpen, store.weeklyQuests.length);
              final maxQuestScroll = _maxQuestScrollHeight(metrics, bothOpen);

              final dailyPanel = _QuestPanel(
                title: 'NHIỆM VỤ HẰNG NGÀY',
                icon: Icons.flag_rounded,
                accent: _gold,
                quests: store.dailyQuests,
                compact: metrics.compact,
                expanded: _dailyExpanded,
                maxVisibleRows: dailyMaxRows,
                onToggle: () => _toggleDaily(metrics),
                onClaim: (id) => _claim(context, id),
              );
              final weeklyPanel = _QuestPanel(
                title: 'NHIỆM VỤ TUẦN',
                icon: Icons.date_range_rounded,
                accent: const Color(0xFF90CAF9),
                quests: store.weeklyQuests,
                compact: metrics.compact,
                expanded: _weeklyExpanded,
                maxVisibleRows: weeklyMaxRows,
                onToggle: () => _toggleWeekly(metrics),
                onClaim: (id) => _claim(context, id),
              );

              final questBody = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dailyPanel,
                  SizedBox(height: gap),
                  weeklyPanel,
                ],
              );

              final playMenu = HomePlayMenu(
                includePadding: false,
                onPlayOffline: widget.onPlayOffline,
                onPlayOnline: widget.onPlayOnline,
                onLeaderboard: widget.onLeaderboard,
                onFriends: widget.onFriends,
              );

              Widget questSection(Widget child) {
                if (metrics.useSideBySide) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: child,
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxQuestScroll),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: child,
                  ),
                );
              }

              if (metrics.useSideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _bothCollapsed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                dailyPanel,
                                SizedBox(height: gap),
                                weeklyPanel,
                              ],
                            )
                          : questSection(questBody),
                    ),
                    SizedBox(width: gap + 4),
                    Expanded(
                      flex: 2,
                      child: Center(child: playMenu),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_bothCollapsed)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dailyPanel,
                        SizedBox(height: gap),
                        weeklyPanel,
                      ],
                    )
                  else if (bothOpen)
                    questSection(questBody)
                  else
                    questBody,
                  SizedBox(height: metrics.compact ? 10 : 14),
                  playMenu,
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, String id) async {
    final store = DailyQuestStore.instance;
    DailyQuest? quest;
    for (final q in store.dailyQuests) {
      if (q.id == id) quest = q;
    }
    for (final q in store.weeklyQuests) {
      if (q.id == id) quest = q;
    }
    if (quest == null) return;

    final err = await store.claim(id);
    if (!context.mounted) return;
    if (err != null) {
      AppSnack.error(context, err, duration: const Duration(milliseconds: 900));
      return;
    }
    AppSnack.coins(context, quest.reward);
  }
}

class _HubMetrics {
  const _HubMetrics({
    required this.maxWidth,
    required this.maxHeight,
    required this.compact,
    required this.wide,
    required this.singlePanelMode,
    required this.useSideBySide,
  });

  final double maxWidth;
  final double maxHeight;
  final bool compact;
  final bool wide;
  final bool singlePanelMode;
  final bool useSideBySide;

  factory _HubMetrics.from(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;
    final compact = HomeLayout.isCompactHub(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final wide = HomeLayout.isWideBox(maxWidth);
    final short = HomeLayout.isShortHub(maxHeight);
    final singlePanelMode = !wide || short || compact;
    final useSideBySide = wide && maxHeight >= 400;

    return _HubMetrics(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      compact: compact,
      wide: wide,
      singlePanelMode: singlePanelMode,
      useSideBySide: useSideBySide,
    );
  }
}

class _QuestPanel extends StatelessWidget {
  const _QuestPanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.quests,
    required this.compact,
    required this.expanded,
    required this.maxVisibleRows,
    required this.onToggle,
    required this.onClaim,
  });

  final int maxVisibleRows;

  final String title;
  final IconData icon;
  final Color accent;
  final List<DailyQuest> quests;
  final bool compact;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onClaim;

  double _rowHeight() => compact ? 42.0 : 48.0;

  double _rowGap() => compact ? 6.0 : 8.0;

  double _listMaxHeight() =>
      maxVisibleRows * _rowHeight() + (maxVisibleRows - 1) * _rowGap();

  EdgeInsets _panelPadding() => compact
      ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
      : const EdgeInsets.fromLTRB(14, 12, 14, 10);

  @override
  Widget build(BuildContext context) {
    final contentH = quests.isEmpty
        ? 0.0
        : quests.length * _rowHeight() + (quests.length - 1) * _rowGap();
    final cap = _listMaxHeight();
    final needsScroll = contentH > cap + 0.5;
    final listH = needsScroll ? cap : contentH;
    final claimable = quests.where((q) => q.canClaim).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x992A0707),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: _panelPadding(),
                  child: Row(
                    children: [
                      Icon(icon, color: accent, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (claimable > 0 && !expanded) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$claimable',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        _panelPadding().left,
                        0,
                        _panelPadding().right,
                        _panelPadding().bottom,
                      ),
                      child: SizedBox(
                        height: listH,
                        child: ListView.separated(
                          primary: false,
                          padding: EdgeInsets.zero,
                          physics: needsScroll
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: quests.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: _rowGap()),
                          itemBuilder: (context, i) => SizedBox(
                            height: _rowHeight(),
                            child: _QuestRow(
                              quest: quests[i],
                              compact: compact,
                              onClaim: () => onClaim(quests[i].id),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.compact,
    required this.onClaim,
  });

  final DailyQuest quest;
  final bool compact;
  final VoidCallback onClaim;

  static const _progressTextStyle = TextStyle(
    color: Color(0xFFECEFF1),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    shadows: [Shadow(color: Color(0x88000000), blurRadius: 2)],
  );

  @override
  Widget build(BuildContext context) {
    final done = quest.isComplete;
    final claimed = quest.claimed;
    final progress = quest.progress / quest.target;
    final hasProgress = quest.progress > 0;
    final fontSize = compact ? 12.0 : 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          quest.icon,
          size: compact ? 16 : 18,
          color: claimed
              ? Colors.white24
              : done
                  ? const Color(0xFF81C784)
                  : Colors.white70,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: TextStyle(
                  color: claimed ? Colors.white38 : Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  decoration: claimed ? TextDecoration.lineThrough : null,
                ),
              ),
              SizedBox(height: compact ? 4 : 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: compact ? 4 : 5,
                  backgroundColor: hasProgress
                      ? const Color(0x28FFFFFF)
                      : const Color(0x38FFC400),
                  color: claimed
                      ? Colors.white24
                      : hasProgress || done
                          ? const Color(0xFFFFC400)
                          : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (quest.canClaim)
          _ClaimChip(label: '+${quest.reward}', onTap: onClaim)
        else if (claimed)
          const Icon(Icons.check_circle, color: Colors.white38, size: 18)
        else
          Text(
            '${quest.progress}/${quest.target}',
            style: _progressTextStyle,
          ),
      ],
    );
  }
}

class _ClaimChip extends StatelessWidget {
  const _ClaimChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 44,
      child: Material(
        color: const Color(0xFFFFC400),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2A0707),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
