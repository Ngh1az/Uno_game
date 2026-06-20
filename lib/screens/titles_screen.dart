import 'package:flutter/material.dart';

import '../daily_quests/daily_quest_store.dart';
import '../titles/title_definition.dart';
import '../titles/title_store.dart';
import '../widgets/title_action_snack.dart';
import '../widgets/title_badge.dart';
import '../widgets/title_name_text.dart';
import '../widgets/title_tier_theme.dart';

/// Màn hình danh hiệu — khung khác nhau theo từng cấp.
class TitlesScreen extends StatefulWidget {
  const TitlesScreen({super.key});

  @override
  State<TitlesScreen> createState() => _TitlesScreenState();
}

class _TitlesScreenState extends State<TitlesScreen> {
  static const _card = Color(0xFF2A0707);
  static const _gold = Color(0xFFFFC400);

  static const _tierOrder = [
    TitleTier.starter,
    TitleTier.shop,
    TitleTier.achievement,
    TitleTier.elite,
  ];

  final Set<TitleTier> _expandedTiers = Set<TitleTier>.from(_tierOrder);

  void _toggleTier(TitleTier tier) {
    setState(() {
      if (_expandedTiers.contains(tier)) {
        _expandedTiers.remove(tier);
      } else {
        _expandedTiers.add(tier);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    TitleStore.instance.markAllUnlocksSeen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0505),
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: Colors.white,
        title: const Text(
          'Danh hiệu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          TitleStore.instance,
          DailyQuestStore.instance,
        ]),
        builder: (context, _) {
          final store = TitleStore.instance;
          final coins = DailyQuestStore.instance.coins;

          return Column(
            children: [
              _summaryBar(store, coins),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    for (final tier in _tierOrder) ...[
                      _sectionHeader(
                        tier,
                        store,
                        expanded: _expandedTiers.contains(tier),
                        onToggle: () => _toggleTier(tier),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _expandedTiers.contains(tier)
                            ? Column(
                                children: [
                                  const SizedBox(height: 8),
                                  for (final def in store.catalog.where(
                                    (t) => t.tier == tier,
                                  )) ...[
                                    _titleTile(context, def),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(
    TitleTier tier,
    TitleStore store, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final accent = TitleTierTheme.sectionAccent(tier);
    final count = store.catalog.where((t) => t.tier == tier).length;
    final unlocked = store.catalog
        .where((t) => t.tier == tier && store.isUnlocked(t.id))
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(TitleTierTheme.sectionIcon(tier), color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierLabel(tier).toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      TitleTierTheme.sectionHint(tier),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '$unlocked/$count',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
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
    );
  }

  Widget _summaryBar(TitleStore store, int coins) {
    final equipped = store.equippedTitle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0x992A0707),
        border: Border(bottom: BorderSide(color: Color(0x33FFD54F))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded, color: _gold, size: 18),
              const SizedBox(width: 6),
              Text(
                '$coins xu UNO',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${store.unlockedCount}/${store.catalog.length} đã mở',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          if (equipped != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Đang đeo: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                TitleBadge(title: equipped, compact: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _titleTile(BuildContext context, TitleDefinition def) {
    final store = TitleStore.instance;
    final unlocked = store.isUnlocked(def.id);
    final equipped = store.equippedId == def.id;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleTierTheme.iconFrame(def: def, unlocked: unlocked),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TitleTierTheme.tierChip(def),
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
                    ],
                  ),
                ),
              ],
            ),
            if (!unlocked && def.hasAchievement) ...[
              const SizedBox(height: 10),
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
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                if (unlocked) ...[
                  if (equipped)
                    const Text(
                      'Đang đeo',
                      style: TextStyle(color: _gold, fontSize: 12),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        store.equip(def.id);
                        TitleActionSnack.showEquipped(context, def);
                      },
                      child: const Text('Đeo', style: TextStyle(color: _gold)),
                    ),
                  if (equipped)
                    TextButton(
                      onPressed: () {
                        store.unequip();
                        TitleActionSnack.showUnequipped(context);
                      },
                      child: const Text(
                        'Bỏ đeo',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                ] else ...[
                  if (canClaim)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: def.color,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _claim(context, def),
                      child: const Text('Nhận'),
                    ),
                  if (canBuy)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: Color(0x88FFD54F)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _buy(context, def),
                      child: Text('Mua ${def.price} xu'),
                    ),
                  if (!canClaim && !canBuy)
                    Text(
                      def.isOnlineExclusive
                          ? 'Chỉ mở bằng thắng online'
                          : 'Chưa mở khóa',
                      style: TextStyle(
                        color: def.isOnlineExclusive
                            ? const Color(0xFFFF8A65)
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
              ),
            ),
          ],
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
