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
    });
  });
}
