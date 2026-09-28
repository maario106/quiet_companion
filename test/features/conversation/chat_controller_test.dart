import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_tts_service.dart';

class FakeGeminiService implements GeminiService {
  int sessionsStarted = 0;
  bool failNext = false;

  @override
  void startSession(String? elderName) => sessionsStarted++;

  @override
  Future<GeminiResponse> sendMessage(String text) async {
    if (failNext) {
      failNext = false;
      return const GeminiResponse(text: 'Upss…', failed: true);
    }
    return GeminiResponse(text: 'Respuesta a: $text');
  }
}

class FakeSpeechService implements SpeechService {
  @override
  Future<bool> initiate() async => true;

  @override
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
  }) {}

  @override
  String stopListening() => '';

  @override
  void cancelListening() {}

  @override
  String get transcript => '';

  @override
  bool get isListening => false;
}

class RecordingCloser implements ConversationCloser {
  final closed = <ClosedConversation>[];

  @override
  Future<void> close(ClosedConversation conversation) async {
    closed.add(conversation);
  }
}

/// Temporizador controlado a mano: el test decide cuándo vence.
class ManualTimer implements Timer {
  ManualTimer(this.duration, this._onFire);

  final Duration duration;
  final void Function() _onFire;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _onFire();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  late FakeGeminiService gemini;
  late RecordingCloser closer;
  late List<ManualTimer> timers;
  late DateTime clock;
  late bool intentionalExit;

  ChatController build({bool consent = true}) {
    return ChatController(
      gemini,
      FakeSpeechService(),
      FakeTtsService(),
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
}
