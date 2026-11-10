import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/app_router.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';

import '../../helpers/fake_auth_repository.dart';

/// La bienvenida del mayor, con el enrutador de verdad, hasta el paso de
/// elegir modo tras «Entrar sin registrarme».
Future<FakeAuthRepository> enterWithoutAccount(WidgetTester tester) async {
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

  await tester.tap(find.text('Entrar sin registrarme'));
  await tester.pumpAndSettle();
  expect(find.text('¿Cómo prefieres usar la aplicación?'), findsOneWidget);
  return repo;
}

void main() {
  testWidgets('al elegir modo ya no se ofrece entrar como acompañante',
      (tester) async {
    await enterWithoutAccount(tester);

    expect(find.text('Soy el acompañante'), findsNothing);
  });

  testWidgets('la flecha vuelve a «¿Cómo quieres entrar?» y borra la cuenta '
      'anónima', (tester) async {
    final repo = await enterWithoutAccount(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo quieres entrar?'), findsOneWidget);
    expect(find.text('Entrar con Google'), findsOneWidget);
    expect(find.text('Soy el acompañante'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(repo.deletedAnonymousUids, ['anon-uid']);
  });

  testWidgets('el botón atrás del sistema hace lo mismo que la flecha',
      (tester) async {
    final repo = await enterWithoutAccount(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo quieres entrar?'), findsOneWidget);
    expect(repo.deletedAnonymousUids, ['anon-uid']);
  });
}
