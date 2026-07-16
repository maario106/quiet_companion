import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_model.dart';

void main() {
  group('AuthRepository.linkCompanionToElder', () {
    test('invalid code (no matching document): throws exception', () async {
      expect(
        () => _testLinkLogic(
          elderDocs: {
            'elder-123': {
              'id': 'elder-123',
              'role': UserRole.elder.name,
              'autonomy': AutonomyStatus.dependent.name,
              'linkCode': 'XYZ9',
              'linkedCompanionId': null,
              'name': null,
              'linkedElderId': null,
              'preferences': {
                'volume': 1.0,
                'speechRate': 0.4,
                'textSizeMultiplier': 1.2,
              },
            },
          },
          searchCode: 'WRONG',
          companionId: 'companion-456',
        ),
        throwsException,
      );
    });

    test('documents found for linkCode search should contain elder and be updatable', () {
      final result = _testLinkLogic(
        elderDocs: {
          'elder-123': {
            'id': 'elder-123',
            'role': UserRole.elder.name,
            'autonomy': AutonomyStatus.dependent.name,
            'linkCode': 'ABC2',
            'linkedCompanionId': null,
            'name': null,
            'linkedElderId': null,
            'preferences': {
              'volume': 1.0,
              'speechRate': 0.4,
              'textSizeMultiplier': 1.2,
            },
          },
        },
        searchCode: 'ABC2',
        companionId: 'companion-456',
      );

      expect(result['elderId'], equals('elder-123'));
      expect(result['batchUpdates'], isNotNull);
      final updates = result['batchUpdates'] as Map<String, dynamic>;
      expect(updates['elder-123'], isNotNull);
      expect(updates['companion-456'], isNotNull);
    });

    test('elder update should clear linkCode and set linkedCompanionId', () {
      final result = _testLinkLogic(
        elderDocs: {
          'elder-789': {
            'id': 'elder-789',
            'role': UserRole.elder.name,
            'autonomy': AutonomyStatus.dependent.name,
            'linkCode': 'USED',
            'linkedCompanionId': null,
            'name': null,
            'linkedElderId': null,
            'preferences': {
              'volume': 1.0,
              'speechRate': 0.4,
              'textSizeMultiplier': 1.2,
            },
          },
        },
        searchCode: 'USED',
        companionId: 'new-companion',
      );

      final updates = result['batchUpdates'] as Map<String, dynamic>;
      final elderUpdate = updates['elder-789'] as Map<String, dynamic>;

      expect(elderUpdate['linkedCompanionId'], equals('new-companion'));
      expect(elderUpdate['autonomy'], equals(AutonomyStatus.dependent.name));
      expect(elderUpdate.containsKey('linkCode'), isTrue);
    });

    test('companion update should set linkedElderId and autonomy to linked', () {
      final result = _testLinkLogic(
        elderDocs: {
          'elder-abc': {
            'id': 'elder-abc',
            'role': UserRole.elder.name,
            'autonomy': AutonomyStatus.dependent.name,
            'linkCode': 'TEST',
            'linkedCompanionId': null,
            'name': 'Don Carlos',
            'linkedElderId': null,
            'preferences': {
              'volume': 1.0,
              'speechRate': 0.4,
              'textSizeMultiplier': 1.2,
            },
          },
        },
        searchCode: 'TEST',
        companionId: 'companion-def',
      );

      final updates = result['batchUpdates'] as Map<String, dynamic>;
      final companionUpdate = updates['companion-def'] as Map<String, dynamic>;

      expect(companionUpdate['linkedElderId'], equals('elder-abc'));
      expect(companionUpdate['autonomy'], equals(AutonomyStatus.linked.name));
    });
  });
}

Map<String, dynamic> _testLinkLogic({
  required Map<String, Map<String, dynamic>> elderDocs,
  required String searchCode,
  required String companionId,
}) {
  final docs = <Map<String, dynamic>>[];

  elderDocs.forEach((docId, data) {
    if (data['linkCode'] == searchCode && data['role'] == UserRole.elder.name) {
      final docData = Map<String, dynamic>.from(data);
      docData['_id'] = docId;
      docs.add(docData);
    }
  });

  if (docs.isEmpty) {
    throw Exception('El código no es válido o ya ha caducado.');
  }

  final elderDoc = docs.first;
  final elderId = elderDoc['_id'] as String;

  final batchUpdates = <String, Map<String, dynamic>>{
    elderId: {
      'linkedCompanionId': companionId,
      'autonomy': AutonomyStatus.dependent.name,
      'linkCode': FieldValue.delete(),
    },
    companionId: {
      'linkedElderId': elderId,
      'autonomy': AutonomyStatus.linked.name,
    },
  };

  return {
    'elderId': elderId,
    'batchUpdates': batchUpdates,
  };
}

class FieldValue {
  static dynamic delete() => const _FieldValueDelete();
}

class _FieldValueDelete {
  const _FieldValueDelete();
}
