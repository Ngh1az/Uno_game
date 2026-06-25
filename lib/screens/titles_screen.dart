import 'package:flutter/material.dart';

import '../daily_quests/daily_quest_store.dart';
import '../titles/title_definition.dart';
import '../titles/title_store.dart';
import '../widgets/title_action_snack.dart';
import '../widgets/title_name_text.dart';
import '../widgets/title_tier_theme.dart';
import '../widgets/uno_circle_button.dart';

enum _TitleFilter { all, unlocked, locked, claimable }

/// Màn hình danh hiệu — premium tone Home, tab theo cấp.
class TitlesScreen extends StatefulWidget {
  const TitlesScreen({super.key});

  @override
  State<TitlesScreen> createState() => _TitlesScreenState();
}

class _TitlesScreenState extends State<TitlesScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD54F);

  static const _tierOrder = [
    TitleTier.starter,
    TitleTier.shop,
    TitleTier.achievement,
    TitleTier.elite,
  ];

  late final TabController _tabs;
  _TitleFilter _filter = _TitleFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: _initialTab());
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _tabs.index;
      if (idx >= 0 && idx < _tierOrder.length) {
        TitleStore.instance.markTierUnlocksSeen(_tierOrder[idx]);
      }
    });
  }

  int _initialTab() {
    final store = TitleStore.instance;
    for (var i = 0; i < _tierOrder.length; i++) {
      final tier = _tierOrder[i];
      if (!_tierComplete(store, tier)) return i;
    }
    return 0;
  }

  bool _tierComplete(TitleStore store, TitleTier tier) {
    final items = store.catalog.where((t) => t.tier == tier);
    return items.every((t) => store.isUnlocked(t.id));
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final idx = _tabs.index;
    if (idx >= 0 && idx < _tierOrder.length) {
      TitleStore.instance.markTierUnlocksSeen(_tierOrder[idx]);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  bool _matchesFilter(TitleDefinition def, TitleStore store) {
    switch (_filter) {
      case _TitleFilter.all:
        return true;
      case _TitleFilter.unlocked:
        return store.isUnlocked(def.id);
      case _TitleFilter.locked:
        return !store.isUnlocked(def.id);
      case _TitleFilter.claimable:
        return store.canUnlockByAchievement(def) || store.canPurchase(def);
    }
  }

  List<TitleDefinition> _filteredCatalog(TitleStore store, {TitleTier? tier}) {
    return store.catalog.where((def) {
      if (tier != null && def.tier != tier) return false;
      return _matchesFilter(def, store);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF2A0707)),
          Image.asset(
            'assets/images/background/homescreen.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.12),
            color: const Color(0xAAFFFFFF),
            colorBlendMode: BlendMode.modulate,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.25),
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x880D0202),
                  Color(0xEE0D0202),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                TitleStore.instance,
                DailyQuestStore.instance,
              ]),
              builder: (context, _) {
                final store = TitleStore.instance;
                final coins = DailyQuestStore.instance.coins;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _premiumHeader(store, coins),
                    _heroEquipped(store),
                    const SizedBox(height: 16),
                    _filterChips(),
                    _tierTabBar(store),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          for (final tier in _tierOrder)
                            _tierList(store, tier),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumHeader(TitleStore store, int coins) {
    final total = store.catalog.length;
    final unlocked = store.unlockedCount;
    final complete = unlocked >= total && total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 44,
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
                  name: 'DANH HIỆU',
                  tier: TitleTier.elite,
                  accent: _gold,
                  fontSize: 20,
                  letterSpacing: 1.4,
                  shimmer: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: store.newUnlockCount > 0
                      ? _newUnlockBadge(store.newUnlockCount)
                      : const SizedBox(width: 44),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _metaPill(
                icon: Icons.monetization_on_rounded,
                label: '$coins xu',
                accent: _gold,
              ),
              const SizedBox(width: 10),
              _metaPill(
                icon: Icons.emoji_events_outlined,
                label: '$unlocked/$total',
                accent: complete ? _gold : Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x992A0707),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _newUnlockBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x44FF7043),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x88FF7043)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF5252),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count mới',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroEquipped(TitleStore store) {
    final equipped = store.equippedTitle;
    if (equipped == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x882A0707),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33FFD54F)),
          ),
          child: const Row(
            children: [
              Icon(Icons.military_tech_outlined, color: Colors.white38, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chưa đeo danh hiệu — chọn một cái bên dưới',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accent = equipped.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              _gold.withValues(alpha: 0.35),
              accent.withValues(alpha: 0.25),
              const Color(0xFF1A0505),
            ],
          ),
          border: Border.all(color: _gold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              TitleTierTheme.iconFrame(def: equipped, unlocked: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐANG ĐEO',
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TitleNameText(title: equipped, fontSize: 16),
                    const SizedBox(height: 2),
                    Text(
                      tierLabel(equipped.tier),
                      style: TextStyle(
                        color: TitleTierTheme.sectionAccent(equipped.tier),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const filters = [
      _TitleFilter.all,
      _TitleFilter.unlocked,
      _TitleFilter.locked,
      _TitleFilter.claimable,
    ];
    const labels = {
      _TitleFilter.all: 'Tất cả',
      _TitleFilter.unlocked: 'Đã mở',
      _TitleFilter.locked: 'Chưa mở',
      _TitleFilter.claimable: 'Có thể nhận',
    };

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final selected = _filter == f;
          return _filterChip(
            label: labels[f]!,
            selected: selected,
            onTap: () => setState(() => _filter = f),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? _gold : const Color(0x882A0707),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _gold : const Color(0x33FFD54F),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tierTabBar(TitleStore store) {
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      labelColor: _gold,
      unselectedLabelColor: Colors.white54,
      indicatorColor: _gold,
      indicatorWeight: 2.5,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      dividerColor: const Color(0x22FFD54F),
      tabs: [
        for (final tier in _tierOrder)
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tierHasNew(store, tier))
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF5252),
                    ),
                  ),
                Text(tierLabel(tier).toUpperCase()),
              ],
            ),
          ),
      ],
    );
  }

  bool _tierHasNew(TitleStore store, TitleTier tier) {
    return store.catalog
        .where((t) => t.tier == tier)
        .any((t) => store.isUnlockNew(t.id));
  }

  Widget _tierList(TitleStore store, TitleTier tier) {
    final items = _filteredCatalog(store, tier: tier);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Không có danh hiệu phù hợp bộ lọc',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _titleTile(context, items[i]),
    );
  }

  Widget _titleTile(BuildContext context, TitleDefinition def) {
    final store = TitleStore.instance;
    final unlocked = store.isUnlocked(def.id);
    final equipped = store.equippedId == def.id;
    final isNew = store.isUnlockNew(def.id);
    final progress = def.hasAchievement ? store.progressFor(def) : 0;
    final target = def.statTarget ?? 0;
    final canClaim = store.canUnlockByAchievement(def);
    final canBuy = store.canPurchase(def);

    return TitleTierTheme.buildCardShell(
      def: def,
      unlocked: unlocked,
      equipped: equipped,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TitleTierTheme.iconFrame(def: def, unlocked: unlocked),
                      if (isNew) const Positioned(top: -2, right: -2, child: _NewDot()),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (equipped)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'ĐANG ĐEO',
                              style: TextStyle(
                                color: _gold.withValues(alpha: 0.95),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        unlocked
                            ? TitleNameText(title: def, fontSize: 15)
                            : Text(
                                def.name,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          def.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        if (!unlocked && def.hasAchievement) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: target == 0 ? 0 : progress / target,
                              minHeight: 5,
                              backgroundColor: const Color(0x28FFFFFF),
                              color: def.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$progress/$target',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _actionColumn(
              context,
              def,
              unlocked: unlocked,
              equipped: equipped,
              canClaim: canClaim,
              canBuy: canBuy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionColumn(
    BuildContext context,
    TitleDefinition def, {
    required bool unlocked,
    required bool equipped,
    required bool canClaim,
    required bool canBuy,
  }) {
    final store = TitleStore.instance;

    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unlocked) ...[
            if (equipped)
              _ghostBtn(
                label: 'Bỏ đeo',
                onTap: () {
                  store.unequip();
                  TitleActionSnack.showUnequipped(context);
                },
              )
            else
              _goldPillBtn(
                label: 'Đeo',
                onTap: () {
                  store.markUnlockSeen(def.id);
                  store.equip(def.id);
                  TitleActionSnack.showEquipped(context, def);
                },
              ),
          ] else ...[
            if (canClaim)
              _accentPillBtn(
                label: 'Nhận',
                color: def.color,
                onTap: () => _claim(context, def),
              ),
            if (canBuy) ...[
              if (canClaim) const SizedBox(height: 6),
              _outlinePillBtn(
                label: 'Mua ${def.price}',
                onTap: () => _buy(context, def),
              ),
            ],
            if (!canClaim && !canBuy)
              Text(
                def.isOnlineExclusive
                    ? 'Chỉ thắng online'
                    : 'Chưa mở',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: def.isOnlineExclusive
                      ? const Color(0xFFFF8A65)
                      : Colors.white38,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _goldPillBtn({
    required String label,
    required VoidCallback onTap,
    bool expanded = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 36,
          width: expanded ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
            ),
            border: Border.all(color: _gold),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3E2723),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accentPillBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinePillBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x88FFD54F)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostBtn({
    required String label,
    required VoidCallback onTap,
    bool expanded = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 36,
          width: expanded ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, TitleDefinition def) async {
    final err = await TitleStore.instance.unlockFree(def.id);
    if (!context.mounted) return;
    if (err != null) {
      TitleActionSnack.showMessage(context, err, success: false);
      return;
    }
    TitleActionSnack.showMessage(
      context,
      'Mở khóa thành công',
      body: def.name,
      accent: def.color,
      icon: def.icon,
    );
  }

  Future<void> _buy(BuildContext context, TitleDefinition def) async {
    final err = await TitleStore.instance.purchase(def.id);
    if (!context.mounted) return;
    if (err != null) {
      TitleActionSnack.showMessage(context, err, success: false);
      return;
    }
    TitleActionSnack.showMessage(
      context,
      'Mua thành công',
      body: def.name,
      accent: def.color,
      icon: def.icon,
    );
  }
}

class _NewDot extends StatelessWidget {
  const _NewDot({this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF5252),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
