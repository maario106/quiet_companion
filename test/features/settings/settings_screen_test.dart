import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/features/emergency/presentation/emergency_contact_setup_screen.dart';
import 'package:quiet_companion/features/settings/presentation/settings_screen.dart';

const _elderSinConfigurar = UserModel(
  id: 'elder-1',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
);

const _elderConContactoManual = UserModel(
  id: 'elder-2',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
  emergencyContact: EmergencyContact(
    name: 'María',
    phone: '+34600123456',
    source: EmergencyContactSource.manual,
  ),
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

Widget _buildSubject(UserModel user) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  group('visibleSettingsRows (función compartida con HomeScreen)', () {
    test('sin contacto (null) → 1 fila: el botón de ajustes se muestra', () {
      expect(visibleSettingsRows(_elderSinConfigurar), hasLength(1));
    });

    test('contacto manual → 1 fila: el botón de ajustes se muestra', () {
      expect(visibleSettingsRows(_elderConContactoManual), hasLength(1));
    });

    test('contacto de vinculación (companion) → 0 filas: botón oculto', () {
      expect(visibleSettingsRows(_elderAcompanado), isEmpty);
    });

    test('el valor de la fila muestra el nombre o el vacío accionable', () {
      final row = visibleSettingsRows(_elderConContactoManual).single;
      expect(row.value(_elderConContactoManual), equals('María'));
      expect(row.value(_elderSinConfigurar), equals('Sin configurar'));
    });
  });

  group('SettingsScreen', () {
    testWidgets('sin contacto: 1 fila con "Sin configurar"', (tester) async {
      await tester.pumpWidget(_buildSubject(_elderSinConfigurar));
      await tester.pumpAndSettle();

      expect(find.text('Contacto de emergencia'), findsOneWidget);
      expect(find.text('Sin configurar'), findsOneWidget);
    });

    testWidgets('contacto manual: 1 fila con el nombre del contacto',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_elderConContactoManual));
      await tester.pumpAndSettle();

      expect(find.text('Contacto de emergencia'), findsOneWidget);
      expect(find.text('María'), findsOneWidget);
      expect(find.text('Sin configurar'), findsNothing);
    });

    testWidgets('contacto de vinculación: 0 filas', (tester) async {
      await tester.pumpWidget(_buildSubject(_elderAcompanado));
      await tester.pumpAndSettle();

      expect(find.text('Contacto de emergencia'), findsNothing);
    });

    testWidgets('tap en la fila → navega a /settings/emergency-contact',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'emergency-contact',
                builder: (context, state) =>
                    const EmergencyContactSetupScreen(),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider
                .overrideWith((ref) => Stream.value(_elderConContactoManual)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contacto de emergencia'));
      await tester.pumpAndSettle();

      expect(find.byType(EmergencyContactSetupScreen), findsOneWidget);
    });
  });
}
