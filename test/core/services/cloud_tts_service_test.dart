import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/cloud_tts_service.dart';
import 'package:quiet_companion/core/services/tts_audio_player.dart';
import 'package:quiet_companion/core/services/tts_synthesizer.dart';

import '../../helpers/fake_tts_service.dart';

// Ni red ni Firebase ni plugin de audio: se testea la orquestación (troceado,
// prefetch, cancelación y respaldo) contra las dos costuras del servicio.

const String _threeSentences = 'Buenos días, me alegro mucho de verte. '
    '¿Has descansado bien esta noche? '
    '¡Cuéntame cómo te encuentras hoy!';

const String _chunk0 = 'Buenos días, me alegro mucho de verte.';
const String _chunk1 = '¿Has descansado bien esta noche?';
const String _chunk2 = '¡Cuéntame cómo te encuentras hoy!';

/// Cada fragmento se sintetiza a sus propios bytes: así el test afirma *qué*
/// sonó y en qué orden, no solo cuántas veces.
Uint8List _audioOf(String text) => Uint8List.fromList(utf8.encode(text));
String _textOf(Uint8List audio) => utf8.decode(audio);

/// Deja correr las microtareas pendientes sin esperas reales.
Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class RecordingSynthesizer implements TtsSynthesizer {
  RecordingSynthesizer(this.log);

  final List<String> log;
  final List<String> requested = [];

  /// Clave de voz de cada petición, paralela a [requested].
  final List<String> voices = [];

  /// Textos cuya síntesis falla.
  final Set<String> failures = {};

  /// Textos cuya síntesis no responde nunca (para probar el timeout).
  final Set<String> hangs = {};

  /// Con `true`, cada síntesis queda pendiente hasta [complete].
  bool manual = false;
  final Map<String, Completer<Uint8List>> pending = {};

  @override
  Future<Uint8List> synthesize(String text, {required String voice}) {
    requested.add(text);
    voices.add(voice);
    log.add('synth:$text');

    if (failures.contains(text)) {
      return Future<Uint8List>.error(StateError('síntesis caída'));
    }
    if (hangs.contains(text)) return Completer<Uint8List>().future;
    if (!manual) return Future<Uint8List>.value(_audioOf(text));

    final completer = Completer<Uint8List>();
    pending[text] = completer;
    return completer.future;
  }

  void complete(String text) => pending.remove(text)!.complete(_audioOf(text));
}

class RecordingPlayer implements TtsAudioPlayer {
  RecordingPlayer(this.log);

  final List<String> log;
  final List<String> played = [];

  /// Con `true`, la reproducción no termina hasta [finishPlayback].
  bool manual = false;

  /// Textos cuya reproducción lanza (MP3 corrupto, sesión de audio perdida).
  final Set<String> failures = {};

  Completer<void>? _current;

  int stopCalls = 0;
  int disposeCalls = 0;
  double? speed;
  double? volume;

  @override
  Future<void> play(Uint8List mp3) {
    final text = _textOf(mp3);
    played.add(text);
    log.add('play:$text');
    if (failures.contains(text)) {
      return Future<void>.error(StateError('reproducción caída'));
    }
    if (!manual) return Future<void>.value();

    final completer = Completer<void>();
    _current = completer;
    return completer.future;
  }

  void finishPlayback() {
    final completer = _current;
    _current = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    log.add('stop');
    finishPlayback();
  }

  @override
  Future<void> setSpeed(double value) async => speed = value;

  @override
  Future<void> setVolume(double value) async => volume = value;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    finishPlayback();
  }
}

void main() {
  late List<String> log;
  late RecordingSynthesizer synthesizer;
  late RecordingPlayer player;
  late FakeTtsService fallback;
  late CloudTtsService service;

  CloudTtsService build({Duration? chunkTimeout}) => CloudTtsService(
        synthesizer: synthesizer,
        player: player,
        fallback: fallback,
        chunkTimeout: chunkTimeout ?? const Duration(seconds: 4),
      );

  setUp(() {
    log = [];
    synthesizer = RecordingSynthesizer(log);
    player = RecordingPlayer(log);
    fallback = FakeTtsService();
    service = build();
  });

  group('camino feliz', () {
    test('trocea, sintetiza y reproduce en orden', () async {
      await service.speak(_threeSentences);

      expect(synthesizer.requested, equals([_chunk0, _chunk1, _chunk2]));
      expect(player.played, equals([_chunk0, _chunk1, _chunk2]));
      expect(fallback.spoken, isEmpty);
    });
  });

  group('prefetch', () {
    test('sintetiza el fragmento siguiente mientras suena el actual',
        () async {
      player.manual = true;

      final utterance = service.speak(_threeSentences);
      await _settle();

      // El fragmento 1 ya se pidió antes de que empezara a sonar el 0.
      expect(synthesizer.requested, equals([_chunk0, _chunk1]));

      player.finishPlayback();
      await _settle();
      expect(synthesizer.requested, equals([_chunk0, _chunk1, _chunk2]));

      player.finishPlayback();
      await _settle();
      player.finishPlayback();
      await utterance;

      // Prefetch de exactamente uno: nunca hay dos peticiones por delante.
      // Toda locución empieza callando la anterior, de ahí el 'stop' inicial.
      expect(
        log,
        equals([
          'stop',
          'synth:$_chunk0',
          'synth:$_chunk1',
          'play:$_chunk0',
          'synth:$_chunk2',
          'play:$_chunk1',
          'play:$_chunk2',
        ]),
      );
    });
  });

  group('cancelación', () {
    test('stop() a mitad: para el audio, tira lo que llega tarde y vacía la '
        'cola', () async {
      synthesizer.manual = true;
      player.manual = true;

      final utterance = service.speak(_threeSentences);
      await _settle();
      synthesizer.complete(_chunk0);
      await _settle();

      expect(player.played, equals([_chunk0]));
      expect(synthesizer.requested, equals([_chunk0, _chunk1]));

      await service.stop();
      await utterance;

      expect(player.stopCalls, equals(2), reason: 'uno por speak, uno real');
      expect(service.isSpeaking, isFalse);

      // El fragmento en vuelo responde después de la cancelación.
      synthesizer.complete(_chunk1);
      await _settle();

      expect(player.played, equals([_chunk0]), reason: 'audio caducado');
      expect(synthesizer.requested, equals([_chunk0, _chunk1]),
          reason: 'la cola no continúa tras stop()');
    });
  });

  group('respaldo sin reintentos', () {
    test('si falla el primer fragmento, lo dice entero el dispositivo',
        () async {
      synthesizer.failures.add(_chunk0);

      await service.speak(_threeSentences);

      expect(player.played, isEmpty);
      expect(fallback.spoken, equals([_threeSentences]));
      // Un solo intento: no se reintenta ni se piden los siguientes.
      expect(synthesizer.requested, equals([_chunk0]));
    });

    test('si falla un fragmento posterior, solo se repite lo que falta',
        () async {
      synthesizer.failures.add(_chunk1);

      await service.speak(_threeSentences);

      expect(player.played, equals([_chunk0]));
      expect(fallback.spoken, equals(['$_chunk1 $_chunk2']));
      expect(fallback.spoken.single, isNot(contains(_chunk0)),
          reason: 'no se repite lo que el mayor ya ha oído');
    });

    test('el timeout se trata como un fallo', () async {
      synthesizer.hangs.add(_chunk0);
      service = build(chunkTimeout: const Duration(milliseconds: 20));

      await service.speak(_threeSentences);

      expect(player.played, isEmpty);
      expect(fallback.spoken, equals([_threeSentences]));
    });
  });

  group('preferencias', () {
    test('la voz elegida viaja con cada fragmento de la locución', () async {
      await service.applyPreferences(const UserPreferences(voice: 'sulafat'));

      await service.speak(_threeSentences);

      expect(synthesizer.voices, equals(['sulafat', 'sulafat', 'sulafat']));
    });
  });
}
