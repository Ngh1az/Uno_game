import 'package:flutter/material.dart';

class DailyQuest {
  DailyQuest({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  bool get isComplete => progress >= target;
  bool get canClaim => isComplete && !claimed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'progress': progress,
        'claimed': claimed,
      };
}
