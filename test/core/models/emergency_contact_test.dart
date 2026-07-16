import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

void main() {
  group('EmergencyContact', () {
    group('normalizeSpanishPhone', () {
      test('9 dígitos nacionales válidos → E.164', () {
        expect(EmergencyContact.normalizeSpanishPhone('600123456'),
            equals('+34600123456'));
      });

      test('acepta entrada con espacios', () {
        expect(EmergencyContact.normalizeSpanishPhone('600 12 34 56'),
            equals('+34600123456'));
      });

      test('fijo válido (empieza por 9)', () {
        expect(EmergencyContact.normalizeSpanishPhone('912345678'),
            equals('+34912345678'));
      });

      test('112 rechazado (número de emergencia)', () {
        expect(EmergencyContact.normalizeSpanishPhone('112'), isNull);
      });

      test('091 rechazado (número de emergencia)', () {
        expect(EmergencyContact.normalizeSpanishPhone('091'), isNull);
      });

      test('longitud incorrecta rechazada', () {
        expect(EmergencyContact.normalizeSpanishPhone('12345'), isNull);
      });

      test('no empieza por 6-9 rechazado', () {
        expect(EmergencyContact.normalizeSpanishPhone('500123456'), isNull);
      });

      test('vacío rechazado', () {
        expect(EmergencyContact.normalizeSpanishPhone(''), isNull);
      });
    });

    group('fromMapOrNull', () {
      test('mapa completo → contacto', () {
        final contact = EmergencyContact.fromMapOrNull({
          'name': 'María',
          'phone': '+34600123456',
          'source': 'companion',
        });

        expect(contact, isNotNull);
        expect(contact!.name, equals('María'));
        expect(contact.phone, equals('+34600123456'));
        expect(contact.source, equals(EmergencyContactSource.companion));
      });

      test('null → null', () {
        expect(EmergencyContact.fromMapOrNull(null), isNull);
      });

      test('sin phone → null (contacto a medias es peor que ninguno)', () {
        expect(
          EmergencyContact.fromMapOrNull({'name': 'María', 'source': 'manual'}),
          isNull,
        );
      });

      test('phone vacío → null', () {
        expect(
          EmergencyContact.fromMapOrNull({'name': 'María', 'phone': ''}),
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

      test('source ausente → manual', () {
        final contact =
            EmergencyContact.fromMapOrNull({'phone': '+34600123456'});
        expect(contact!.source, equals(EmergencyContactSource.manual));
      });

      test('name ausente o vacío → defaultName (nunca vacío)', () {
        final sinNombre =
            EmergencyContact.fromMapOrNull({'phone': '+34600123456'});
        final vacio = EmergencyContact.fromMapOrNull(
            {'name': '', 'phone': '+34600123456'});
        expect(sinNombre!.name, equals(EmergencyContact.defaultName));
        expect(vacio!.name, equals(EmergencyContact.defaultName));
      });
    });

    group('toMap / round-trip', () {
      test('serializa los tres campos', () {
        const contact = EmergencyContact(
          name: 'María',
          phone: '+34600123456',
          source: EmergencyContactSource.companion,
        );
        expect(contact.toMap(), {
          'name': 'María',
          'phone': '+34600123456',
          'source': 'companion',
        });
      });

      test('fromMapOrNull(toMap()) == original', () {
        const contact = EmergencyContact(
          name: 'María',
          phone: '+34600123456',
          source: EmergencyContactSource.manual,
        );
        expect(EmergencyContact.fromMapOrNull(contact.toMap()), equals(contact));
      });
    });

    group('igualdad', () {
      test('mismos valores → iguales y mismo hashCode', () {
        const a = EmergencyContact(name: 'María', phone: '+34600123456');
        const b = EmergencyContact(name: 'María', phone: '+34600123456');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('distinto phone → no iguales', () {
        const a = EmergencyContact(name: 'María', phone: '+34600123456');
        const b = EmergencyContact(name: 'María', phone: '+34600123457');
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('UserModel + emergencyContact', () {
    const contact = EmergencyContact(
      name: 'María',
      phone: '+34600123456',
      source: EmergencyContactSource.manual,
    );

    test('toMap omite la clave cuando es null', () {
      const user = UserModel(id: 'elder-1');
      expect(user.toMap().containsKey('emergencyContact'), isFalse);
    });

    test('toMap incluye la clave cuando existe', () {
      const user = UserModel(id: 'elder-1', emergencyContact: contact);
      expect(user.toMap()['emergencyContact'], equals(contact.toMap()));
    });

    test('fromMap sin clave → null (documentos anteriores a la feature)', () {
      final user = UserModel.fromMap('elder-1', {'role': 'elder'});
      expect(user.emergencyContact, isNull);
    });

    test('fromMap con contacto inválido (sin phone) → null', () {
      final user = UserModel.fromMap('elder-1', {
        'role': 'elder',
        'emergencyContact': {'name': 'María'},
      });
      expect(user.emergencyContact, isNull);
    });

    test('round-trip conserva el contacto', () {
      const user = UserModel(id: 'elder-1', emergencyContact: contact);
      final restored = UserModel.fromMap('elder-1', user.toMap());
      expect(restored.emergencyContact, equals(contact));
    });

    test('copyWith establece y limpia el contacto (patrón _unset)', () {
      const user = UserModel(id: 'elder-1');
      final withContact = user.copyWith(emergencyContact: contact);
      expect(withContact.emergencyContact, equals(contact));

      final cleared = withContact.copyWith(emergencyContact: null);
      expect(cleared.emergencyContact, isNull);

      final untouched = withContact.copyWith(name: 'Otro');
      expect(untouched.emergencyContact, equals(contact));
    });

    test('phoneNumber sobrevive al round-trip', () {
      const user = UserModel(
        id: 'comp-1',
        role: UserRole.companion,
        phoneNumber: '+34600123456',
      );
      final restored = UserModel.fromMap('comp-1', user.toMap());
      expect(restored.phoneNumber, equals('+34600123456'));
    });
  });
}
