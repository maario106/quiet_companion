import 'package:firebase_auth/firebase_auth.dart' show GoogleAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';
import 'package:quiet_companion/features/settings/presentation/account_screen.dart';

import '../../helpers/fake_auth_repository.dart';

const _elder = UserModel(
  id: 'elder-1',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
);

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(_elder)),
      ],
      child: const MaterialApp(home: AccountScreen()),
    );
  }

  testWidgets('sin registrarse no se ofrece cerrar sesión, y si la cuenta de '
      'Google ya existe se pregunta antes de entrar con ella', (tester) async {
    repo.account = const AuthAccount(isAnonymous: true);
    repo.linkResult =
        GoogleAccountInUse(GoogleAuthProvider.credential(idToken: 'token'));
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Cerrar sesión'), findsNothing);
    // Con la letra del mayor, el botón queda por debajo de los 600 px del test.
    await tester.ensureVisible(find.text('Guardar con Google'));
    await tester.tap(find.text('Guardar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar con esa cuenta'), findsOneWidget);
    expect(find.text('No, seguir así'), findsOneWidget);
  });

  testWidgets('con Google, cerrar sesión pide un segundo toque',
      (tester) async {
    repo.account = const AuthAccount(isAnonymous: false, email: 'm@gmail.com');
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    expect(repo.signOutCalls, 0);

    await tester.tap(find.text('Sí, cerrar sesión'));
    await tester.pump();
    expect(repo.signOutCalls, 1);
  });
}
