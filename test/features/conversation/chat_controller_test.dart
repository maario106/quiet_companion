import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';
import 'package:quiet_companion/features/conversation/domain/chat_state.dart';

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

    test('salida al marcador de emergencia → no se cierra', () async {
      final controller = build();
      await talk(controller, 3);
      intentionalExit = true;

      controller.onAppPaused();

      expect(closer.closed, isEmpty);
    });

    test('sin consentimiento, la conversación se cierra pero no sale nada',
        () async {
      final controller = build(consent: false);
      await talk(controller, 3);

      controller.onAppPaused();

      expect(closer.closed, isEmpty);
    });
  });

  group('historial que viaja a chatTurn', () {
    test('cada turno lleva los anteriores de la conversación, no el suyo',
        () async {
      final controller = build();
      await talk(controller, 2);

      await controller.sendMessage('tercera');

      expect(gemini.lastHistory.map((t) => t.text), [
        'frase 0',
        'Respuesta a: frase 0',
        'frase 1',
        'Respuesta a: frase 1',
      ]);
    });

    test('un turno fallido no entra, y el siguiente no lo arrastra', () async {
      final controller = build();
      await talk(controller, 1);
      gemini.failNext = true;
      await controller.sendMessage('se corta');

      await controller.sendMessage('repito');

      expect(gemini.lastHistory, hasLength(2));
    });

    test('tras el cierre, la conversación nueva empieza sin historial',
        () async {
      final controller = build();
      await talk(controller, 3);
      timers.last.fire();

      await controller.sendMessage('hola otra vez');

      expect(gemini.lastHistory, isEmpty);
    });
  });

  group('modo teclado (ADR-0035)', () {
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
  });
}
