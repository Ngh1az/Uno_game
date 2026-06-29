import 'package:flutter_test/flutter_test.dart';
import 'package:uno_game/friends/friends_service.dart';
import 'package:uno_game/user/player_display_name.dart';

void main() {
  group('PlayerDisplayName', () {
    test('isDefaultGuestName', () {
      expect(PlayerDisplayName.isDefaultGuestName('Khách'), isTrue);
      expect(PlayerDisplayName.isDefaultGuestName('  Khách  '), isTrue);
      expect(PlayerDisplayName.isDefaultGuestName('Người chơi'), isTrue);
      expect(PlayerDisplayName.isDefaultGuestName(''), isTrue);
      expect(PlayerDisplayName.isDefaultGuestName('Minh'), isFalse);
    });

    test('roomLabel uses suffix for default names', () {
      expect(
        PlayerDisplayName.roomLabel('Khách', 'abc123xyz789'),
        'Khách #Z789',
      );
      expect(
        PlayerDisplayName.roomLabel('Minh', 'abc123xyz789'),
        'Minh',
      );
    });

    test('uidSuffix', () {
      expect(PlayerDisplayName.uidSuffix('ab'), 'AB');
      expect(PlayerDisplayName.uidSuffix('abcdef'), 'CDEF');
    });
  });

  group('FriendsService.displayLabel', () {
    test('matches roomLabel for default and custom names', () {
      expect(
        FriendsService.displayLabel('Khách', 'uid1234abcd'),
        PlayerDisplayName.roomLabel('Khách', 'uid1234abcd'),
      );
      expect(
        FriendsService.displayLabel('Người chơi', 'uid1234abcd'),
        PlayerDisplayName.roomLabel('Khách', 'uid1234abcd'),
      );
      expect(
        FriendsService.displayLabel('Lan', 'uid1234abcd'),
        'Lan',
      );
      expect(
        FriendsService.displayLabel(null, 'uid1234abcd'),
        PlayerDisplayName.roomLabel('Khách', 'uid1234abcd'),
      );
    });
  });
}
