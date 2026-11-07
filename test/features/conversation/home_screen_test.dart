import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_consent.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';
import 'package:quiet_companion/features/conversation/presentation/home_screen.dart';

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

final _analyzed = ConversationRecord(
  id: 'c1',
  startedAt: DateTime(2026, 10, 1, 10),
  endedAt: DateTime(2026, 10, 1, 10, 5),
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
      // Un temporizador real de inactividad quedaría pendiente al acabar.
      startTimer: ManualTimer.new,
    );
  });

  Widget buildSubject({UserModel user = _elder}) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        chatControllerProvider.overrideWith((ref) => controller),
        conversationRecordsProvider
            .overrideWith((ref, elderId) => Stream.value([_analyzed])),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  Future<void> openKeyboardMode(
    WidgetTester tester, {
    UserModel user = _elder,
  }) async {
    await tester.pumpWidget(buildSubject(user: user));
    await tester.pump();
    await tester.tap(find.text('¿Teclado?'));
    await tester.pump();
  }

  group('modo teclado (ADR-0035)', () {
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
  });

  testWidgets('con la letra más grande, la pantalla cabe en un teléfono '
      'estrecho: el saludo no se corta y el micrófono mengua', (tester) async {
    // Teléfono de gama media, 360 × 800 dp, y con "Mi semana" visible: el
    // caso con menos sitio.
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    const user = UserModel(
      id: 'elder-1',
      name: 'Carmen',
      role: UserRole.elder,
      autonomy: AutonomyStatus.independent,
      preferences: UserPreferences(textSizeMultiplier: 2.0),
      conversationConsent: ConversationConsent(granted: true),
    );

    await tester.pumpWidget(buildSubject(user: user));
    // Hasta que acaba la animación del micrófono al llegar la preferencia.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mi semana'), findsOneWidget);
    final greeting =
        tester.renderObject<RenderParagraph>(find.text('Hola, Carmen'));
    expect(greeting.didExceedMaxLines, isFalse);
    final mic = find.ancestor(
      of: find.byIcon(Icons.mic_none),
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.getSize(mic), const Size(140, 140));
  });
}
