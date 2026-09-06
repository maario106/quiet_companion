import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Costura de reproducción de audio. Igual que [TtsSynthesizer], existe para
/// que la lógica de [CloudTtsService] se pueda testear sin plugins.
abstract interface class TtsAudioPlayer {
  /// Reproduce [mp3] y completa cuando termina de sonar (o cuando [stop] lo
  /// interrumpe). Esta es la señal que mantiene los fragmentos en orden.
  ///
  /// **El contrato crítico es "cuando termina de sonar"**: si una
  /// implementación completa antes, el fragmento siguiente pisa al actual y la
  /// respuesta se oye a trozos. Ningún test puede detectarlo —el doble de
  /// test cumple el contrato por construcción—, así que se verifica en
  /// dispositivo.
  Future<void> play(Uint8List mp3);

  /// Detiene la reproducción en curso. Idempotente.
  Future<void> stop();

  /// Velocidad de reproducción (1.0 = ritmo sintetizado).
  Future<void> setSpeed(double speed);

  /// Volumen de reproducción (0.0 – 1.0).
  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// Implementación sobre `just_audio`. Reproduce desde memoria: los fragmentos
/// llegan como bytes de la callable y no se escriben nunca a disco (el
/// contenido es conversación de una persona mayor — política de minimización
/// de datos del proyecto).
class JustAudioTtsPlayer implements TtsAudioPlayer {
  JustAudioTtsPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Margen sobre la duración de la pista antes de darla por terminada sin
  /// haber recibido el evento de fin.
  static const Duration _completionGrace = Duration(seconds: 2);

  /// Espera máxima cuando el reproductor no sabe cuánto dura el audio. Un
  /// fragmento son una o dos frases: nunca se acerca a este techo.
  static const Duration _completionFallback = Duration(seconds: 30);

  @override
  Future<void> play(Uint8List mp3) async {
    await _player.setAudioSource(_Mp3BytesSource(mp3));

    // El futuro de play() NO sirve para saber cuándo acaba la pista: la propia
    // documentación de just_audio dice que "si el reproductor ya está
    // reproduciendo, este método completa de inmediato", y `playing` sigue
    // siendo true después de cada pista (solo pause() o stop() lo bajan). Con
    // varias frases seguidas eso hacía que el fragmento i+1 cortara al i: se
    // oía la primera frase y la última. La señal fiable es el estado del
    // reproductor.
    final finished = _player.processingStateStream.firstWhere(
      (state) =>
          state == ProcessingState.completed || state == ProcessingState.idle,
    );

    await _player.play();

    // Red de seguridad: si el evento de fin se perdiera, la conversación se
    // quedaría congelada en "hablando" para siempre. Se espera como mucho lo
    // que dura el audio a la velocidad actual, más un margen.
    final duration = _player.duration;
    final speed = _player.speed;
    await finished.timeout(
      duration != null && speed > 0
          ? duration * (1 / speed) + _completionGrace
          : _completionFallback,
      onTimeout: () => ProcessingState.completed,
    );
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Fuente de audio en memoria. `just_audio` no acepta bytes directamente:
/// exige un [StreamAudioSource] que sirva el rango pedido.
class _Mp3BytesSource extends StreamAudioSource {
  _Mp3BytesSource(this._bytes);

  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(_bytes.sublist(from, to)),
      contentType: 'audio/mpeg',
    );
  }
}
