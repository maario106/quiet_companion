import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';
import 'package:quiet_companion/features/conversation/presentation/home_screen.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_gemini_service.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/manual_timer.dart';

// Sin consentimiento: "Mi semana" ni se consulta, y la pantalla no necesita
// Firestore.
const _elder = UserModel(
  id: 'elder-1',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
);

void main() {
  late FakeGeminiService gemini;
  late FakeTtsService tts;
  late ChatController controller;

  setUp(() {
    gemini = FakeGeminiService();
    tts = FakeTtsService();
    controller = ChatController(
      gemini,
      FakeSpeechService(),
      tts,
      FakeAuthRepository(),
      _elder.id,
      null,
      // Un temporizador real de inactividad quedaría pendiente al acabar.
      startTimer: ManualTimer.new,
    );
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_elder)),
        chatControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  Future<void> openKeyboardMode(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.tap(find.text('¿Teclado?'));
    await tester.pump();
  }

  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

  group('modo teclado (ADR-0035)', () {
    testWidgets('"¿Teclado?" cambia el micrófono por el campo, y "¿Hablar?" '
        'lo devuelve', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('¿Teclado?'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Escuchar'), findsOneWidget);

      await tester.tap(find.text('¿Hablar?'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('¿Teclado?'), findsOneWidget);
    });

    testWidgets('sin texto, "Enviar" está apagado', (tester) async {
      await openKeyboardMode(tester);
      expect(sendButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'hola');
      await tester.pump();
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('lo escrito se envía, el campo se vacía y la respuesta se '
        'enseña sin leerla', (tester) async {
      await openKeyboardMode(tester);

      await tester.enterText(find.byType(TextField), 'Me llamo Carmen');
      await tester.pump();
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(gemini.sent, ['Me llamo Carmen']);
      expect(find.text('Respuesta a: Me llamo Carmen'), findsOneWidget);
      expect(tts.spoken, isEmpty);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('si el turno falla, el texto vuelve al campo', (tester) async {
      await openKeyboardMode(tester);
      gemini.failNext = true;

      await tester.enterText(find.byType(TextField), 'Me llamo Carmen');
      await tester.pump();
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Me llamo Carmen');
    });

    testWidgets('"Escuchar" lee la respuesta en voz alta', (tester) async {
      await openKeyboardMode(tester);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();

      expect(tts.spoken, ['Hola! ¿De qué quieres que hablemos hoy?']);
    });
  });
}
