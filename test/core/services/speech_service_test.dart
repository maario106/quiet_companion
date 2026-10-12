import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/speech_config.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Reconocedor nativo de mentira. El test decide qué avisa y en qué orden,
/// que es justo lo que Android no garantiza.
///
/// Imita lo que hace el paquete 7.3.0 encima del plugin: `notListening` pasa
/// en el acto, pero `done` se retiene hasta que se ha entregado el final, salvo
/// que la sesión no oyera nada (`doneNoResult`).
class FakeRecognizer extends Fake implements stt.SpeechToText {
  late stt.SpeechStatusListener _onStatus;
  late stt.SpeechErrorListener _onError;
  stt.SpeechResultListener? _onResult;

  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool _listening = false;
  bool _heard = false;

  @override
  bool get isListening => _listening;

  // `initialize` y `listen` tienen firmas largas con tipos de paquetes
  // transitivos; se interceptan aquí para no tener que repetirlas.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      _onStatus =
          invocation.namedArguments[#onStatus] as stt.SpeechStatusListener;
      _onError = invocation.namedArguments[#onError] as stt.SpeechErrorListener;
      return Future.value(true);
    }
    if (invocation.memberName == #listen) {
      listenCalls++;
      _onResult =
          invocation.namedArguments[#onResult] as stt.SpeechResultListener;
      _listening = true;
      _heard = false;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    // Como el plugin: solo avisa si de verdad estaba grabando.
    if (!_listening) return;
    _endOfSpeech();
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _listening = false;
  }

  void partial(String words) => _result(words, finalResult: false);

  void finalResult(String words) => _result(words, finalResult: true);

  /// Android deja de grabar tras una pausa. El final, si lo hay, llega luego.
  void endOfSpeech() => _endOfSpeech();

  void error(String message) {
    _onError(SpeechRecognitionError(message, true));
    if (_listening) _endOfSpeech();
  }

  void _endOfSpeech() {
    _listening = false;
    _onStatus(stt.SpeechToText.notListeningStatus);
    if (!_heard) _onStatus(stt.SpeechToText.doneStatus);
  }

  void _result(String words, {required bool finalResult}) {
    _heard = true;
    _onResult?.call(SpeechRecognitionResult(
      [SpeechRecognitionWords(words, null, 0.9)],
      finalResult,
    ));
    // El `done` retenido sale detrás del final.
    if (finalResult) _onStatus(stt.SpeechToText.doneStatus);
  }
}

void main() {
  const pause = Duration(seconds: 3);

  late FakeRecognizer recognizer;
  late SpeechService service;
  late List<String> finals;
  late List<String> partials;

  Future<void> begin({Duration silenceTimeout = pause}) async {
    await service.initiate();
    service.beginListening(
      onPartial: partials.add,
      onFinal: finals.add,
      silenceTimeout: silenceTimeout,
    );
  }

  setUp(() {
    recognizer = FakeRecognizer();
    service = SpeechService(speechToText: recognizer);
    finals = [];
    partials = [];
  });

  group('la última palabra (ADR-0036)', () {
    testWidgets('llega en el final, DESPUÉS de notListening, y no se pierde',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('me llamo');
      recognizer.endOfSpeech();
      recognizer.finalResult('me llamo Mario');
      await tester.pump(pause);

      expect(finals, ['me llamo Mario']);
    });

    testWidgets('el botón espera al final antes de enviar', (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('quiero contarte');
      expect(service.finishListening(), isTrue);
      expect(recognizer.stopCalls, 1);
      expect(finals, isEmpty);

      recognizer.finalResult('quiero contarte algo');
      expect(finals, ['quiero contarte algo']);
    });

    testWidgets('si el final no llega, el tope cierra con lo que haya',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('hola');
      service.finishListening();
      await tester.pump(kSpeechFinalResultWait);

      expect(finals, ['hola']);
    });

    testWidgets('un error que se adelanta al final no lo tira ni lo duplica',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('hola');
      recognizer.error('error_no_match');
      recognizer.finalResult('hola qué tal');
      await tester.pump(pause);

      expect(finals, ['hola qué tal']);
    });
  });

  group('turno de varias sesiones (ADR-0022)', () {
    testWidgets('una pausa a media frase reanuda y acumula sin duplicar',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('hola');
      recognizer.endOfSpeech();
      recognizer.finalResult('hola qué tal');
      await tester.pump(kSpeechResumeDelay);
      expect(recognizer.listenCalls, 2);

      recognizer.partial('estoy bien');
      recognizer.endOfSpeech();
      recognizer.finalResult('estoy bien');
      await tester.pump(pause);

      expect(finals, ['hola qué tal estoy bien']);
      expect(partials.last, 'hola qué tal estoy bien');
    });

    testWidgets('sin final ni error, el micrófono no se queda sordo',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('hola');
      recognizer.endOfSpeech();
      await tester.pump(kSpeechFinalResultWait + kSpeechResumeDelay);

      expect(recognizer.listenCalls, 2);
      service.cancelListening();
    });
  });

  group('cierre por silencio', () {
    testWidgets('manda la pausa que trae el turno', (tester) async {
      await begin(silenceTimeout: const Duration(seconds: 6));
      await tester.pump();

      recognizer.partial('estaba pensando');
      await tester.pump(const Duration(seconds: 5));
      expect(finals, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(kSpeechFinalResultWait);
      expect(finals, ['estaba pensando']);
    });

    testWidgets('el final que repite el parcial no alarga la espera',
        (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('hola');
      await tester.pump(const Duration(seconds: 2));
      recognizer.endOfSpeech();
      recognizer.finalResult('hola');
      await tester.pump(const Duration(seconds: 1));

      expect(finals, ['hola']);
    });

    testWidgets('sin hablar, se cierra vacío tras la espera inicial',
        (tester) async {
      await begin();
      await tester.pump(kSpeechLeadInTimeout);

      expect(finals, ['']);
    });

    testWidgets('con una pausa más larga que la espera inicial, manda la pausa',
        (tester) async {
      await begin(silenceTimeout: const Duration(seconds: 10));
      await tester.pump(kSpeechLeadInTimeout);
      expect(finals, isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(finals, ['']);
    });
  });

  group('fin del turno desde fuera', () {
    testWidgets('finishListening sin turno abierto devuelve false',
        (tester) async {
      expect(service.finishListening(), isFalse);

      await begin();
      service.cancelListening();
      expect(service.finishListening(), isFalse);
    });

    testWidgets('cancelar descarta lo oído y no avisa', (tester) async {
      await begin();
      await tester.pump();

      recognizer.partial('algo');
      service.cancelListening();
      recognizer.finalResult('algo más');
      await tester.pump(pause + kSpeechFinalResultWait);

      expect(finals, isEmpty);
      expect(recognizer.cancelCalls, 1);
    });
  });
}
