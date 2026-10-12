import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_consent.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
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

// Con consentimiento y una conversación analizada: Inicio enseña "Mi semana",
// que se aparta mientras el teclado del sistema está abierto.
final _elderWithMyWeek = _elder.copyWith(
  conversationConsent: const ConversationConsent(granted: true),
);
final _analyzed = ConversationRecord(
  id: 'c1',
  startedAt: DateTime(2026, 10, 1, 10),
  endedAt: DateTime(2026, 10, 1, 10, 5),
);

/// Alto que el teclado del sistema le quita a la pantalla, en píxeles lógicos.
const _keyboardHeight = 300.0;

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

  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

  /// Pantalla de móvil: con la de los tests (800 × 600) Inicio se ve como en
  /// una tableta y el teclado no dejaría sitio.
  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  /// Lo que hace la plataforma cuando el teclado del sistema aparece o se va:
  /// le quita o le devuelve el sitio a la pantalla.
  Future<void> setKeyboardInset(WidgetTester tester, {required bool open}) async {
    tester.view.viewInsets = open
        ? FakeViewPadding(bottom: _keyboardHeight * tester.view.devicePixelRatio)
        : FakeViewPadding.zero;
    await tester.pump();
  }

  bool fieldHasFocus(WidgetTester tester) => tester
      .state<EditableTextState>(find.byType(EditableText))
      .widget
      .focusNode
      .hasFocus;

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

    testWidgets('tocar fuera del campo cierra el teclado y vuelve "Escuchar"',
        (tester) async {
      usePhoneScreen(tester);
      await openKeyboardMode(tester, user: _elderWithMyWeek);
      await setKeyboardInset(tester, open: true);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Escuchar'), findsNothing);

      await tester.tap(find.text('Hola! ¿De qué quieres que hablemos hoy?'));
      await tester.pump();
      expect(fieldHasFocus(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await setKeyboardInset(tester, open: false);
      expect(find.text('Escuchar'), findsOneWidget);
      expect(find.text('Mi semana'), findsOneWidget);
    });

    testWidgets('"Cerrar teclado" cierra el teclado del sistema',
        (tester) async {
      usePhoneScreen(tester);
      await openKeyboardMode(tester, user: _elderWithMyWeek);
      await setKeyboardInset(tester, open: true);

      await tester.tap(find.byTooltip('Cerrar teclado'));
      await tester.pump();
      expect(fieldHasFocus(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      // Sin teclado no hay nada que cerrar: el botón se va.
      await setKeyboardInset(tester, open: false);
      expect(find.byTooltip('Cerrar teclado'), findsNothing);
    });

    testWidgets('abrir y cerrar el teclado no rehace el campo: no pierde el '
        'foco ni lo escrito', (tester) async {
      usePhoneScreen(tester);
      await openKeyboardMode(tester, user: _elderWithMyWeek);
      final field = tester.state(find.byType(EditableText));
      await tester.enterText(find.byType(TextField), 'Hola');

      await setKeyboardInset(tester, open: true);
      expect(tester.state(find.byType(EditableText)), same(field));
      expect(fieldHasFocus(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await setKeyboardInset(tester, open: false);
      expect(tester.state(find.byType(EditableText)), same(field));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Hola',
      );
    });

    testWidgets('si el sistema cierra el teclado, tocar el campo lo vuelve a '
        'abrir', (tester) async {
      usePhoneScreen(tester);
      await openKeyboardMode(tester, user: _elderWithMyWeek);
      await setKeyboardInset(tester, open: true);

      // Atrás del móvil, cambiar de app...: el teclado se va sin que la app
      // lo pida.
      tester.testTextInput.hide();
      await setKeyboardInset(tester, open: false);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await setKeyboardInset(tester, open: true);
      expect(fieldHasFocus(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('tras cerrar el teclado, tocar el campo lo vuelve a abrir',
        (tester) async {
      usePhoneScreen(tester);
      await openKeyboardMode(tester, user: _elderWithMyWeek);
      await setKeyboardInset(tester, open: true);
      await tester.tap(find.text('Hola! ¿De qué quieres que hablemos hoy?'));
      await tester.pump();
      await setKeyboardInset(tester, open: false);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await setKeyboardInset(tester, open: true);
      expect(fieldHasFocus(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });
}
