import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';

void main() {
  group('EmergencyContact', () {
    group('normalizeSpanishPhone', () {
      test('9 dígitos nacionales válidos → E.164', () {
        expect(EmergencyContact.normalizeSpanishPhone('600123456'),
            equals('+34600123456'));
      });

      test('112 rechazado (número de emergencia)', () {
        expect(EmergencyContact.normalizeSpanishPhone('112'), isNull);
      });
    });

    group('fromMapOrNull', () {
      test('sin phone → null (contacto a medias es peor que ninguno)', () {
        expect(
          EmergencyContact.fromMapOrNull({'name': 'María', 'source': 'manual'}),
          isNull,
        );
      });

      test('source desconocido → manual (fallback conservador)', () {
        final contact = EmergencyContact.fromMapOrNull({
          'phone': '+34600123456',
          'source': 'algo-raro',
        });
        expect(contact!.source, equals(EmergencyContactSource.manual));
      });
    });
  });
}
