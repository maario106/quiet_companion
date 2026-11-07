import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

const _elderSinConfigurar = UserModel(
  id: 'elder-1',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
);

const _elderAcompanado = UserModel(
  id: 'elder-3',
  role: UserRole.elder,
  autonomy: AutonomyStatus.dependent,
  emergencyContact: EmergencyContact(
    name: 'María',
    phone: '+34600123456',
    source: EmergencyContactSource.companion,
  ),
);

void main() {
  group('visibleSettingsRows (función compartida con HomeScreen)', () {
    test('contacto de vinculación (companion) → oculta el contacto, deja las '
        '4 escalas: el botón de ajustes ya no desaparece', () {
      expect(visibleSettingsRows(_elderAcompanado), hasLength(7));
      expect(
        visibleSettingsRows(_elderAcompanado)
            .any((row) => row.title == 'Contacto de emergencia'),
        isFalse,
      );
    });

    test('el menú: cuatro entradas; «Mis datos» avisa si falta el contacto y '
        'no lo anuncia si lo fija el familiar', () {
      expect(
        visibleSettingsEntries(_elderSinConfigurar).map((e) => e.title),
        equals([
          'Mis datos',
          'Tamaño de la letra',
          'Cómo hablamos',
          'Mis conversaciones',
        ]),
      );

      final personal = settingsGroupBySlug('personal')!;
      expect(personal.subtitleFor(_elderSinConfigurar), contains('Falta'));
      expect(
        personal.visibleRows(_elderAcompanado).map((row) => row.title),
        equals(['Mi cuenta']),
      );
      expect(
        personal.subtitleFor(_elderAcompanado),
        isNot(contains('contacto')),
      );
    });
  });
}
