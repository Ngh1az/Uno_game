import 'package:flutter/material.dart';

import '../daily_quests/daily_quest.dart';
import '../daily_quests/daily_quest_store.dart';
import 'app_snack.dart';
import 'home_layout.dart';

/// Panel nhiệm vụ hằng ngày — gọn, trong suốt, đồng bộ khối chơi.
class HomeDailyQuests extends StatelessWidget {
  const HomeDailyQuests({super.key});

  static const _gold = Color(0xFFFFD54F);

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x992A0707),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x44FFD54F)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(store.coins, store.claimableCount),
                  const SizedBox(height: 10),
                  for (var i = 0; i < store.quests.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _QuestRow(
                      quest: store.quests[i],
                      onClaim: () => _claim(context, store.quests[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(int coins, int claimable) {
    return Row(
      children: [
        const Icon(Icons.flag_rounded, color: _gold, size: 18),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'NHIỆM VỤ HẰNG NGÀY',
            style: TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        if (claimable > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$claimable',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        const Icon(Icons.monetization_on_rounded, color: _gold, size: 16),
        const SizedBox(width: 2),
        Text(
          '$coins',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _claim(BuildContext context, String id) async {
    final err = await DailyQuestStore.instance.claim(id);
    if (!context.mounted) return;
    if (err != null) {
      AppSnack.error(context, err, duration: const Duration(milliseconds: 900));
      return;
    }
    final reward = DailyQuestStore.instance.quests
        .firstWhere((q) => q.id == id)
        .reward;
    AppSnack.coins(context, reward);
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest, required this.onClaim});

  final DailyQuest quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = quest.isComplete;
    final claimed = quest.claimed;
    final progress = quest.progress / quest.target;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          quest.icon,
          size: 18,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: claimed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0x28FFFFFF),
                  color: claimed
                      ? Colors.white24
                      : const Color(0xFFFFC400),
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
