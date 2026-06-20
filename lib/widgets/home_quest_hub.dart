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
  });

  final VoidCallback onPlayOffline;
  final VoidCallback onPlayOnline;

  @override
  State<HomeQuestHub> createState() => _HomeQuestHubState();
}

class _HomeQuestHubState extends State<HomeQuestHub> {
  static const _gold = Color(0xFFFFD54F);

  bool _dailyExpanded = true;
  bool _weeklyExpanded = true;

  bool get _bothCollapsed => !_dailyExpanded && !_weeklyExpanded;

  int _maxVisibleRows(double hubHeight, bool bothOpen) {
    if (!bothOpen) return 4;
    if (hubHeight < 300) return 2;
    if (hubHeight < 400) return 3;
    return 4;
  }

  void _toggleDaily(bool tight) {
    setState(() {
      final opening = !_dailyExpanded;
      _dailyExpanded = opening;
      if (opening && tight) _weeklyExpanded = false;
    });
  }

  void _toggleWeekly(bool tight) {
    setState(() {
      final opening = !_weeklyExpanded;
      _weeklyExpanded = opening;
      if (opening && tight) _dailyExpanded = false;
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
              final tight = constraints.maxHeight < 560;
              final gap = tight ? 6.0 : 8.0;
              final bothOpen = _dailyExpanded && _weeklyExpanded;
              final maxRows = _maxVisibleRows(constraints.maxHeight, bothOpen);

              final dailyPanel = _QuestPanel(
                title: 'NHIỆM VỤ HẰNG NGÀY',
                icon: Icons.flag_rounded,
                accent: _gold,
                quests: store.dailyQuests,
                compact: tight,
                expanded: _dailyExpanded,
                maxVisibleRows: maxRows,
                onToggle: () => _toggleDaily(tight),
                onClaim: (id) => _claim(context, id),
              );
              final weeklyPanel = _QuestPanel(
                title: 'NHIỆM VỤ TUẦN',
                icon: Icons.date_range_rounded,
                accent: const Color(0xFF90CAF9),
                quests: store.weeklyQuests,
                compact: tight,
                expanded: _weeklyExpanded,
                maxVisibleRows: maxRows,
                onToggle: () => _toggleWeekly(tight),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _bothCollapsed
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              dailyPanel,
                              SizedBox(height: gap),
                              weeklyPanel,
                            ],
                          )
                        : SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: questBody,
                          ),
                  ),
                  SizedBox(height: gap),
                  HomePlayMenu(
                    includePadding: false,
                    compact: true,
                    onPlayOffline: widget.onPlayOffline,
                    onPlayOnline: widget.onPlayOnline,
                  ),
                  SizedBox(height: tight ? 2 : 6),
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

  double _rowHeight() => compact ? 40.0 : 44.0;

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
    final listH = contentH.clamp(0.0, _listMaxHeight());
    final needsScroll = contentH > _listMaxHeight() + 0.5;
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

  @override
  Widget build(BuildContext context) {
    final done = quest.isComplete;
    final claimed = quest.claimed;
    final progress = quest.progress / quest.target;
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
                  value: progress,
                  minHeight: compact ? 4 : 5,
                  backgroundColor: const Color(0x28FFFFFF),
                  color: claimed ? Colors.white24 : const Color(0xFFFFC400),
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
            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    return Material(
      color: const Color(0xFFFFC400),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}
