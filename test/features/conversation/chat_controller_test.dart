import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';
import 'package:quiet_companion/features/conversation/domain/chat_state.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_gemini_service.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/manual_timer.dart';

class RecordingCloser implements ConversationCloser {
  final closed = <ClosedConversation>[];

  @override
  Future<void> close(ClosedConversation conversation) async {
    closed.add(conversation);
  }
}

/// Deja correr lo que esté pendiente (respuestas del modelo, voces cortadas).
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeGeminiService gemini;
  late FakeSpeechService speech;
  late FakeTtsService tts;
  late RecordingCloser closer;
  late List<ManualTimer> timers;
  late DateTime clock;
  late bool intentionalExit;

  ChatController build({bool consent = true}) {
    return ChatController(
      gemini,
      speech,
      tts,
      FakeAuthRepository(),
      'elder-1',
      'Carmen',
      closer: closer,
      consentGranted: consent,
      settings: const ConversationSettings(inactivityMinutes: 5),
      isIntentionalExit: () => intentionalExit,
      now: () => clock,
      startTimer: (duration, onFire) {
        final timer = ManualTimer(duration, onFire);
        timers.add(timer);
        return timer;
      },
    );
  }

  Future<void> talk(ChatController controller, int turns) async {
    for (var i = 0; i < turns; i++) {
      await controller.sendMessage('frase $i');
      clock = clock.add(const Duration(seconds: 30));
    }
  }

  setUp(() {
    gemini = FakeGeminiService();
    speech = FakeSpeechService();
    tts = FakeTtsService();
    closer = RecordingCloser();
    timers = [];
    clock = DateTime(2026, 9, 26, 10);
    intentionalExit = false;
  });

  group('frontera de la conversación (ADR-0028)', () {
    test('vence la inactividad → se envía una vez, con los turnos', () async {
      final controller = build();
      await talk(controller, 3);

      expect(timers.last.duration, const Duration(minutes: 5));
      timers.last.fire();

      expect(closer.closed, hasLength(1));
      final closed = closer.closed.single;
      expect(closed.endReason, ConversationEndReason.inactivity);
      expect(closed.elderTurns, 3);
      expect(closed.turns, hasLength(6)); // mayor + asistente, por turno
    });

    test('salida a segundo plano → se envía con endReason background', () async {
      final controller = build();
      await talk(controller, 3);

      controller.onAppPaused();

      expect(closer.closed.single.endReason, ConversationEndReason.background);
    });

    test('salida al marcador de emergencia → no se cierra', () async {
      final controller = build();
      await talk(controller, 3);
      intentionalExit = true;

      controller.onAppPaused();

      expect(closer.closed, isEmpty);
    });

    test('al volver tras el plazo, se cierra aunque el temporizador no venciera',
        () async {
      final controller = build();
      await talk(controller, 3);
      intentionalExit = true;
      controller.onAppPaused();

      clock = clock.add(const Duration(minutes: 6));
      controller.onAppResumed();

      expect(closer.closed.single.endReason, ConversationEndReason.inactivity);
    });

    test('menos de 3 turnos del mayor → se envía sin texto', () async {
      final controller = build();
      await talk(controller, 2);

      controller.onAppPaused();

      expect(closer.closed.single.elderTurns, 2);
      expect(closer.closed.single.turns, isNull);
    });

    test('las respuestas de error no entran en el búfer', () async {
      final controller = build();
      await talk(controller, 3);
      gemini.failNext = true;
      await controller.sendMessage('esto falla');

      controller.onAppPaused();

      expect(closer.closed.single.elderTurns, 3);
    });

    test('tras el cierre, el siguiente turno empieza sesión nueva del modelo',
        () async {
      final controller = build();
      await talk(controller, 3);
      final sessionsBefore = gemini.sessionsStarted;
      controller.onAppPaused();

      await controller.sendMessage('hola otra vez');

      expect(gemini.sessionsStarted, sessionsBefore + 1);
    });

    test('sin consentimiento, la conversación se cierra pero no sale nada',
        () async {
      final controller = build(consent: false);
      await talk(controller, 3);

      controller.onAppPaused();

      expect(closer.closed, isEmpty);
    });

    test('sin conversación en curso, salir de la app no envía nada', () {
      final controller = build();

      controller.onAppPaused();

      expect(closer.closed, isEmpty);
    });
  });

  group('memoria del mayor (ADR-0032)', () {
    const memory = ElderMemory(facts: {'ciudad': 'Sevilla'});

    test('con consentimiento, la sesión nueva lleva la memoria', () async {
      final controller = build();
      controller.updateMemory(memory);

      await controller.sendMessage('hola');

      expect(gemini.lastMemory, same(memory));
    });

    test('sin consentimiento, la memoria no se inyecta', () async {
      final controller = build(consent: false);
      controller.updateMemory(memory);

      await controller.sendMessage('hola');

      expect(gemini.lastMemory, isNull);
    });

    test('una memoria nueva no reinicia la conversación en curso', () async {
      final controller = build();
      await talk(controller, 2);
      final sessionsBefore = gemini.sessionsStarted;

      controller.updateMemory(memory);
      await controller.sendMessage('sigo contando');

      expect(gemini.sessionsStarted, sessionsBefore);
    });

    test('cambiar el nombre a mitad resiembra conservando el hilo', () async {
      final controller = build();
      await talk(controller, 2);

      controller.updateElderName('Carmen María');

      expect(gemini.lastHistory, hasLength(4));
      expect(gemini.lastHistory.first.role, ConversationRole.elder);
    });
  });

  group('modo teclado (ADR-0035)', () {
    test('un turno escrito enseña la respuesta sin leerla', () async {
      final controller = build();

      final answered = await controller.sendTypedMessage('hola');

      expect(answered, isTrue);
      expect(tts.spoken, isEmpty);
      expect(controller.state.status, ChatStatus.initial);
      expect(controller.state.responseAI, 'Respuesta a: hola');
    });

    test('los turnos escritos cuentan para el análisis como los hablados',
        () async {
      final controller = build();
      for (var i = 0; i < 3; i++) {
        await controller.sendTypedMessage('frase $i');
      }

      controller.onAppPaused();

      expect(closer.closed.single.elderTurns, 3);
      expect(closer.closed.single.turns, hasLength(6));
    });

    test('si el modelo falla, lo dice para devolver el texto al campo',
        () async {
      final controller = build();
      gemini.failNext = true;

      expect(await controller.sendTypedMessage('hola'), isFalse);
    });

    test('con un turno esperando respuesta no se envía otro', () async {
      final controller = build();
      gemini.gate = Completer<void>();
      final first = controller.sendTypedMessage('uno');

      expect(await controller.sendTypedMessage('dos'), isFalse);

      gemini.gate!.complete();
      await first;
      expect(gemini.sent, ['uno']);
    });

    test('escribir con la voz sonando la calla, y esa voz no pisa el turno',
        () async {
      final controller = build();
      tts.blockUntilFinished = true;
      final spoken = controller.sendMessage('hablado');
      await settle();
      expect(controller.state.status, ChatStatus.talking);

      gemini.gate = Completer<void>();
      final typed = controller.sendTypedMessage('escrito');
      await settle();

      expect(tts.stopCalls, 1);
      expect(controller.state.status, ChatStatus.thinking);

      gemini.gate!.complete();
      await Future.wait([spoken, typed]);
      expect(controller.state.status, ChatStatus.initial);
      expect(controller.state.responseAI, 'Respuesta a: escrito');
    });

    test('"Escuchar" lee la respuesta y "Parar" la corta', () async {
      final controller = build();
      await controller.sendTypedMessage('hola');
      tts.blockUntilFinished = true;

      final reading = controller.readReplyAloud();
      await settle();
      expect(tts.spoken, ['Respuesta a: hola']);
      expect(controller.state.status, ChatStatus.talking);

      controller.stopSpeaking();
      await reading;

      expect(controller.state.status, ChatStatus.initial);
    });

    test('pasar al teclado con el micrófono abierto descarta la escucha',
        () async {
      final controller = build();
      await controller.startListening();
      expect(controller.state.status, ChatStatus.listening);

      controller.setInputMode(InputMode.keyboard);

      expect(speech.cancelCalls, 1);
      expect(controller.state.status, ChatStatus.initial);
      expect(controller.state.inputMode, InputMode.keyboard);
    });
  });

  group('escucha (ADR-0036)', () {
    test('el turno se abre con la pausa que eligió el mayor', () async {
      final controller = build();
      await controller.startListening();
      expect(speech.lastSilenceTimeout, const Duration(seconds: 3));

      speech.deliverFinal('');
      controller.updateListenPause(const Duration(seconds: 6));
      await controller.startListening();

      expect(speech.lastSilenceTimeout, const Duration(seconds: 6));
    });

    test('el botón espera a lo último que oyó el reconocedor', () async {
      final controller = build();
      await controller.startListening();

      controller.stopListeningAndSend();
      expect(speech.finishCalls, 1);
      expect(controller.state.status, ChatStatus.listening);
      expect(gemini.sent, isEmpty);

      speech.deliverFinal('me llamo Carmen');
      await settle();

      expect(gemini.sent, ['me llamo Carmen']);
    });

    test('si otra pantalla canceló la escucha, el botón vuelve a reposo',
        () async {
      final controller = build();
      await controller.startListening();
      speech.cancelListening();

      controller.stopListeningAndSend();

      expect(controller.state.status, ChatStatus.initial);
      expect(gemini.sent, isEmpty);
    });
  });
}
