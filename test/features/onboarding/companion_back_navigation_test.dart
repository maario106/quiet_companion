import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/app_router.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  testWidgets('la flecha deshace los pasos del familiar hasta la bienvenida, '
      'también después de entrar en «Ya tengo una cuenta»', (tester) async {
    final repo = FakeAuthRepository();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      firebaseAuthUserProvider.overrideWith((ref) => Stream.value(null)),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
      ),
    ));
    repo.signInAs(null); // Sin sesión: la bienvenida.
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Soy el acompañante'));
    await tester.tap(find.text('Soy el acompañante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Acceso para acompañantes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Soy el acompañante'), findsOneWidget);
  });
}
