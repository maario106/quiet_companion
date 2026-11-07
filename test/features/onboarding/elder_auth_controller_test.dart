import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_state.dart';

import '../../helpers/fake_auth_repository.dart';

/// Deja llegar los eventos de sesión y las lecturas del documento.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthRepository repo;
  late ElderAuthController controller;

  setUp(() async {
    repo = FakeAuthRepository();
    controller = ElderAuthController(repo);
    repo.signInAs(null); // Arranque sin sesión.
    await settle();
  });

  tearDown(() => controller.dispose());

  test('sin sesión no entra en anónimo: espera a que el mayor elija', () {
    expect(controller.state.status, AuthStatus.nonAuthenticated);
    expect(repo.anonymousSignIns, 0);
  });

  test('cerrar el selector de Google vuelve a la bienvenida sin aviso',
      () async {
    repo.googleUid = null;

    await controller.signInWithGoogle();

    expect(controller.state.status, AuthStatus.nonAuthenticated);
    expect(controller.state.errorMessage, isEmpty);
  });

  test('una cuenta de Google de mayor recupera su documento (móvil nuevo)',
      () async {
    repo.users['g-1'] = const UserModel(
      id: 'g-1',
      role: UserRole.elder,
      autonomy: AutonomyStatus.independent,
    );
    repo.googleUid = 'g-1';

    await controller.signInWithGoogle();
    await settle();

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.autonomy, AutonomyStatus.independent);
  });

  test('la cuenta de Google de un familiar no entra como mayor, y se dice',
      () async {
    repo.users['fam-1'] = const UserModel(id: 'fam-1', role: UserRole.companion);
    repo.googleUid = 'fam-1';

    await controller.signInWithGoogle();
    await settle();

    expect(repo.signedInUid, isNull);
    expect(controller.state.status, AuthStatus.error);
    expect(controller.state.user, isNull);
    expect(controller.state.errorMessage, contains('familiar'));
  });
}
