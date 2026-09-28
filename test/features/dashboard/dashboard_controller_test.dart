import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  group('DashboardController', () {
    group('updateElderPreference', () {
      test('escribe solo el campo tocado, sobre el mayor vinculado', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderPreference(UserPreferences.volumeKey, 0.5);

        expect(repo.preferenceWrites, [('elder-1', 'volume', 0.5)]);
        expect(controller.state.errorMessage, isNull);
      });

      test('si la escritura falla, deja un mensaje de error', () async {
        final repo = FakeAuthRepository(shouldThrow: true);
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderPreference(
            UserPreferences.speechRateKey, 0.6);

        expect(controller.state.errorMessage, isNotNull);
      });

      test('sin mayor vinculado no escribe nada', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, null);

        await controller.updateElderPreference(UserPreferences.volumeKey, 0.5);

        expect(repo.preferenceWrites, isEmpty);
      });
    });

    group('updateElderName', () {
      test('escribe el nombre recortado', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('  María  ');

        expect(repo.nameWrites, [('elder-1', 'María')]);
      });

      test('ignora nombres vacíos', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('   ');

        expect(repo.nameWrites, isEmpty);
      });

      test('si la escritura falla, deja un mensaje de error', () async {
        final repo = FakeAuthRepository(shouldThrow: true);
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('María');

        expect(controller.state.errorMessage, isNotNull);
      });
    });

    test('clearError limpia el mensaje', () async {
      final repo = FakeAuthRepository(shouldThrow: true);
      final controller = DashboardController(repo, 'elder-1');
      await controller.updateElderName('María');

      controller.clearError();

      expect(controller.state.errorMessage, isNull);
    });
  });
}
