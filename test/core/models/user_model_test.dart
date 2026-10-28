import 'package:flutter_test/flutter_test.dart' show equals, expect, group, isNull, test;
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

void main() {
  group('UserModel', () {
    group('fromMap', () {
      test('uses default autonomy (none) when autonomy is null or missing', () {
        const uid = 'test-uid';
        final map = {
          'role': 'elder',
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.autonomy, equals(AutonomyStatus.none));
      });
    });

    group('round-trip (fromMap(toMap(model)) == model)', () {
      test('preserves all fields after round-trip', () {
        final original = UserModel(
          id: 'uid-abc',
          name: 'Bob',
          role: UserRole.companion,
          autonomy: AutonomyStatus.dependent,
          linkCode: 'LINK',
          linkedCompanionId: 'comp-xyz',
          linkedElderId: 'elder-def',
          preferences: const UserPreferences(
            volume: 0.5,
            speechRate: 0.6,
            textSizeMultiplier: 1.1,
          ),
        );

        final map = original.toMap();
        final recovered = UserModel.fromMap(original.id, map);

        expect(recovered.id, equals(original.id));
        expect(recovered.name, equals(original.name));
        expect(recovered.role, equals(original.role));
        expect(recovered.autonomy, equals(original.autonomy));
        expect(recovered.linkCode, equals(original.linkCode));
        expect(recovered.linkedCompanionId, equals(original.linkedCompanionId));
        expect(recovered.linkedElderId, equals(original.linkedElderId));
        expect(recovered.preferences.volume, equals(original.preferences.volume));
        expect(recovered.preferences.speechRate, equals(original.preferences.speechRate));
        expect(recovered.preferences.textSizeMultiplier, equals(original.preferences.textSizeMultiplier));
      });
    });

    group('copyWith', () {
      test('copyWith(linkCode: null) clears the linkCode field', () {
        final original = UserModel(
          id: 'uid-1',
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkCode: 'OLDCODE',
        );

        final updated = original.copyWith(linkCode: null);

        expect(updated.linkCode, isNull);
        expect(updated.autonomy, equals(original.autonomy));
      });
    });
  });
}
