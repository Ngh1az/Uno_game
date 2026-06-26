import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/security/action_rate_limit.dart';

void main() {
  group('statChunkStep', () {
    test('đã đạt target → 0', () {
      expect(ProgressBounds.statChunkStep(50, 50, 15), 0);
      expect(ProgressBounds.statChunkStep(100, 50, 15), 0);
    });

    test('tăng từng bước theo maxDelta', () {
      expect(ProgressBounds.statChunkStep(0, 50, 15), 15);
      expect(ProgressBounds.statChunkStep(45, 50, 15), 5);
      expect(ProgressBounds.statChunkStep(48, 50, 5), 2);
    });

    test('khớp delta Firestore rules', () {
      // gamesPlayed +15, offlineWins +5, onlineJoins +10, onlineWins +5
      expect(ProgressBounds.statChunkStep(0, 100, 15), 15);
      expect(ProgressBounds.statChunkStep(0, 100, 5), 5);
      expect(ProgressBounds.statChunkStep(0, 100, 10), 10);
    });
  });
}
