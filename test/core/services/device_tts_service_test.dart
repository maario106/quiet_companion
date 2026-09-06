import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/device_tts_service.dart';

// El motor TTS del dispositivo no se testea (es el plugin): se comprueba que
// el envoltorio lo configura como antes de la migración y que no traduce las
// preferencias — en la escala de flutter_tts van tal cual.

String _nameOf(Invocation invocation) {
  final raw = invocation.memberName.toString(); // Symbol("setLanguage")
  return raw.substring('Symbol("'.length, raw.length - 2);
}

class FakeFlutterTts implements FlutterTts {
  final List<String> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments.join(', ');
    calls.add('${_nameOf(invocation)}($args)');
    return Future<dynamic>.value(1);
  }
}

void main() {
  late FakeFlutterTts flutterTts;
  late DeviceTtsService service;

  setUp(() {
    flutterTts = FakeFlutterTts();
    service = DeviceTtsService(flutterTts: flutterTts);
  });

  test('se configura en español y espera a que termine la locución', () async {
    // La inicialización del constructor es asíncrona.
    await Future<void>.delayed(Duration.zero);

    expect(flutterTts.calls, contains('setLanguage(es-ES)'));
    expect(flutterTts.calls, contains('setPitch(1.0)'));
    // Sin esto, el flujo de conversación reanudaría la escucha encima de la
    // voz.
    expect(flutterTts.calls, contains('awaitSpeakCompletion(true)'));
  });

  test('las preferencias pasan sin traducir a la escala de flutter_tts',
      () async {
    await service.applyPreferences(
      const UserPreferences(volume: 0.8, speechRate: 0.4),
    );

    expect(flutterTts.calls, contains('setVolume(0.8)'));
    expect(flutterTts.calls, contains('setSpeechRate(0.4)'));
  });

  test('speak habla y devuelve el control al terminar', () async {
    expect(service.isSpeaking, isFalse);

    await service.speak('Buenos días.');

    expect(flutterTts.calls, contains('speak(Buenos días.)'));
    expect(service.isSpeaking, isFalse);
  });

  test('stop corta la locución', () async {
    await service.stop();

    expect(flutterTts.calls, contains('stop()'));
    expect(service.isSpeaking, isFalse);
  });
}
