import 'package:flutter_test/flutter_test.dart' show equals, expect, group, isNull, test;
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

void main() {
  group('UserModel', () {
    group('fromMap', () {
      test('deserializes all fields including nullable name, linkCode, linkedCompanionId, linkedElderId', () {
        const uid = 'test-uid';
        final map = {
          'id': uid,
          'name': 'John Doe',
          'role': 'elder',
          'autonomy': 'independent',
          'linkCode': 'ABC2',
          'linkedCompanionId': 'companion-uid',
          'linkedElderId': 'elder-uid',
          'preferences': {
            'volume': 0.8,
            'speechRate': 0.5,
            'textSizeMultiplier': 1.3,
          },
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.id, equals(uid));
        expect(user.name, equals('John Doe'));
        expect(user.role, equals(UserRole.elder));
        expect(user.autonomy, equals(AutonomyStatus.independent));
        expect(user.linkCode, equals('ABC2'));
        expect(user.linkedCompanionId, equals('companion-uid'));
        expect(user.linkedElderId, equals('elder-uid'));
        expect(user.preferences.volume, equals(0.8));
        expect(user.preferences.speechRate, equals(0.5));
        expect(user.preferences.textSizeMultiplier, equals(1.3));
      });

      test('deserializes nullable fields as null when absent', () {
        const uid = 'test-uid';
        final map = {
          'role': 'companion',
          'autonomy': 'none',
          'preferences': {
            'volume': 1.0,
            'speechRate': 0.4,
            'textSizeMultiplier': 1.2,
          },
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.name, isNull);
        expect(user.linkCode, isNull);
        expect(user.linkedCompanionId, isNull);
        expect(user.linkedElderId, isNull);
      });

      test('uses default role (unassigned) when role is null or missing', () {
        const uid = 'test-uid';
        final map = {
          'autonomy': 'none',
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.role, equals(UserRole.unassigned));
      });

      test('uses default autonomy (none) when autonomy is null or missing', () {
        const uid = 'test-uid';
        final map = {
          'role': 'elder',
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.autonomy, equals(AutonomyStatus.none));
      });

      test('creates default UserPreferences when preferences is null or missing', () {
        const uid = 'test-uid';
        final map = {
          'role': 'elder',
          'autonomy': 'independent',
        };

        final user = UserModel.fromMap(uid, map);

        expect(user.preferences.volume, equals(1.0));
        expect(user.preferences.speechRate, equals(0.4));
        expect(user.preferences.textSizeMultiplier, equals(1.2));
      });
    });

    group('toMap', () {
      test('serializes all fields correctly', () {
        final user = UserModel(
          id: 'uid-123',
          name: 'Alice',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
          linkCode: 'XYZ9',
          linkedCompanionId: 'comp-123',
          linkedElderId: 'elder-456',
          preferences: const UserPreferences(
            volume: 0.7,
            speechRate: 0.3,
            textSizeMultiplier: 1.5,
          ),
        );

        final map = user.toMap();

        expect(map['id'], equals('uid-123'));
        expect(map['name'], equals('Alice'));
        expect(map['role'], equals('elder'));
        expect(map['autonomy'], equals('independent'));
        expect(map['linkCode'], equals('XYZ9'));
        expect(map['linkedCompanionId'], equals('comp-123'));
        expect(map['linkedElderId'], equals('elder-456'));
        expect(map['preferences']['volume'], equals(0.7));
        expect(map['preferences']['speechRate'], equals(0.3));
        expect(map['preferences']['textSizeMultiplier'], equals(1.5));
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

      test('round-trip with null optional fields', () {
        final original = UserModel(
          id: 'uid-null-test',
          role: UserRole.elder,
          autonomy: AutonomyStatus.none,
        );

        final map = original.toMap();
        final recovered = UserModel.fromMap(original.id, map);

        expect(recovered.id, equals(original.id));
        expect(recovered.name, isNull);
        expect(recovered.linkCode, isNull);
        expect(recovered.linkedCompanionId, isNull);
        expect(recovered.linkedElderId, isNull);
      });
    });

    group('copyWith', () {
      test('updates only specified fields', () {
        final original = UserModel(
          id: 'uid-1',
          name: 'Original',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
          linkCode: 'CODE1',
        );

        final updated = original.copyWith(name: 'Updated');

        expect(updated.id, equals(original.id));
        expect(updated.name, equals('Updated'));
        expect(updated.role, equals(original.role));
        expect(updated.autonomy, equals(original.autonomy));
        expect(updated.linkCode, equals(original.linkCode));
      });

      test('copyWith(name: null) clears the name field', () {
        final original = UserModel(
          id: 'uid-1',
          name: 'HasName',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );

        final updated = original.copyWith(name: null);

        expect(updated.name, isNull);
        expect(updated.role, equals(original.role));
      });

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

      test('copyWith(linkedCompanionId: null) clears linkedCompanionId', () {
        final original = UserModel(
          id: 'uid-1',
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkedCompanionId: 'comp-123',
        );

        final updated = original.copyWith(linkedCompanionId: null);

        expect(updated.linkedCompanionId, isNull);
        expect(updated.id, equals(original.id));
      });

      test('copyWith(linkedElderId: null) clears linkedElderId', () {
        final original = UserModel(
          id: 'uid-1',
          role: UserRole.companion,
          autonomy: AutonomyStatus.linked,
          linkedElderId: 'elder-456',
        );

        final updated = original.copyWith(linkedElderId: null);

        expect(updated.linkedElderId, isNull);
        expect(updated.role, equals(original.role));
      });

      test('copyWith multiple fields', () {
        final original = UserModel(
          id: 'uid-1',
          name: 'Old',
          role: UserRole.elder,
          autonomy: AutonomyStatus.none,
        );

        final updated = original.copyWith(
          name: 'New',
          autonomy: AutonomyStatus.independent,
          linkCode: 'NEWCODE',
        );

        expect(updated.name, equals('New'));
        expect(updated.autonomy, equals(AutonomyStatus.independent));
        expect(updated.linkCode, equals('NEWCODE'));
        expect(updated.role, equals(original.role));
      });
    });

    group('enum parsing', () {
      test('parses UserRole enum correctly', () {
        const uid = 'test-uid';
        final mapElder = {'role': 'elder'};
        final mapCompanion = {'role': 'companion'};
        final mapUnassigned = {'role': 'unassigned'};

        final userElder = UserModel.fromMap(uid, mapElder);
        final userCompanion = UserModel.fromMap(uid, mapCompanion);
        final userUnassigned = UserModel.fromMap(uid, mapUnassigned);

        expect(userElder.role, equals(UserRole.elder));
        expect(userCompanion.role, equals(UserRole.companion));
        expect(userUnassigned.role, equals(UserRole.unassigned));
      });

      test('parses AutonomyStatus enum correctly', () {
        const uid = 'test-uid';
        final mapIndependent = {'autonomy': 'independent'};
        final mapDependent = {'autonomy': 'dependent'};
        final mapLinked = {'autonomy': 'linked'};
        final mapNone = {'autonomy': 'none'};

        final userIndependent = UserModel.fromMap(uid, mapIndependent);
        final userDependent = UserModel.fromMap(uid, mapDependent);
        final userLinked = UserModel.fromMap(uid, mapLinked);
        final userNone = UserModel.fromMap(uid, mapNone);

        expect(userIndependent.autonomy, equals(AutonomyStatus.independent));
        expect(userDependent.autonomy, equals(AutonomyStatus.dependent));
        expect(userLinked.autonomy, equals(AutonomyStatus.linked));
        expect(userNone.autonomy, equals(AutonomyStatus.none));
      });
    });
  });

  group('UserPreferences', () {
    group('fromMap', () {
      test('deserializes all fields correctly', () {
        final map = {
          'volume': 0.6,
          'speechRate': 0.8,
          'textSizeMultiplier': 1.4,
        };

        final prefs = UserPreferences.fromMap(map);

        expect(prefs.volume, equals(0.6));
        expect(prefs.speechRate, equals(0.8));
        expect(prefs.textSizeMultiplier, equals(1.4));
      });

      test('uses defaults when fields are missing', () {
        final map = <String, dynamic>{};

        final prefs = UserPreferences.fromMap(map);

        expect(prefs.volume, equals(1.0));
        expect(prefs.speechRate, equals(0.4));
        expect(prefs.textSizeMultiplier, equals(1.2));
      });

      test('uses defaults when fields are null', () {
        final map = {
          'volume': null,
          'speechRate': null,
          'textSizeMultiplier': null,
        };

        final prefs = UserPreferences.fromMap(map);

        expect(prefs.volume, equals(1.0));
        expect(prefs.speechRate, equals(0.4));
        expect(prefs.textSizeMultiplier, equals(1.2));
      });
    });

    group('toMap', () {
      test('serializes all fields correctly', () {
        const prefs = UserPreferences(
          volume: 0.5,
          speechRate: 0.7,
          textSizeMultiplier: 1.3,
        );

        final map = prefs.toMap();

        expect(map['volume'], equals(0.5));
        expect(map['speechRate'], equals(0.7));
        expect(map['textSizeMultiplier'], equals(1.3));
      });
    });

    group('round-trip (fromMap(toMap(prefs)) == prefs)', () {
      test('preserves all fields after round-trip', () {
        const original = UserPreferences(
          volume: 0.3,
          speechRate: 0.6,
          textSizeMultiplier: 1.5,
        );

        final map = original.toMap();
        final recovered = UserPreferences.fromMap(map);

        expect(recovered.volume, equals(original.volume));
        expect(recovered.speechRate, equals(original.speechRate));
        expect(recovered.textSizeMultiplier, equals(original.textSizeMultiplier));
      });

      test('round-trip with defaults', () {
        const original = UserPreferences();

        final map = original.toMap();
        final recovered = UserPreferences.fromMap(map);

        expect(recovered.volume, equals(original.volume));
        expect(recovered.speechRate, equals(original.speechRate));
        expect(recovered.textSizeMultiplier, equals(original.textSizeMultiplier));
      });
    });

    group('copyWith', () {
      test('updates only specified fields', () {
        const original = UserPreferences(
          volume: 0.7,
          speechRate: 0.5,
          textSizeMultiplier: 1.1,
        );

        final updated = original.copyWith(volume: 0.9);

        expect(updated.volume, equals(0.9));
        expect(updated.speechRate, equals(original.speechRate));
        expect(updated.textSizeMultiplier, equals(original.textSizeMultiplier));
      });

      test('copyWith multiple fields', () {
        const original = UserPreferences(
          volume: 1.0,
          speechRate: 0.4,
          textSizeMultiplier: 1.2,
        );

        final updated = original.copyWith(
          speechRate: 0.6,
          textSizeMultiplier: 1.4,
        );

        expect(updated.volume, equals(original.volume));
        expect(updated.speechRate, equals(0.6));
        expect(updated.textSizeMultiplier, equals(1.4));
      });

      test('copyWith all fields', () {
        const original = UserPreferences();

        final updated = original.copyWith(
          volume: 0.5,
          speechRate: 0.7,
          textSizeMultiplier: 1.6,
        );

        expect(updated.volume, equals(0.5));
        expect(updated.speechRate, equals(0.7));
        expect(updated.textSizeMultiplier, equals(1.6));
      });
    });
  });
}
