import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Reproducción de audio, separada para testear [CloudTtsService] sin plugins.
abstract interface class TtsAudioPlayer {
  /// Reproduce [mp3] y completa cuando termina de sonar (o lo para [stop]). Si
  /// completara antes, los fragmentos se pisarían.
  Future<void> play(Uint8List mp3);

  /// Detiene la reproducción en curso. Idempotente.
  Future<void> stop();

  /// Velocidad de reproducción (1.0 = ritmo sintetizado).
  Future<void> setSpeed(double speed);

  /// Volumen de reproducción (0.0 a 1.0).
  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// Sobre just_audio. Reproduce desde memoria: el audio nunca se escribe a disco.
class JustAudioTtsPlayer implements TtsAudioPlayer {
  JustAudioTtsPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Margen sobre la duración de la pista si no llega el evento de fin.
  static const Duration _completionGrace = Duration(seconds: 2);

  /// Espera máxima si no se conoce la duración.
  static const Duration _completionFallback = Duration(seconds: 30);

  @override
  Future<void> play(Uint8List mp3) async {
    await _player.setAudioSource(_Mp3BytesSource(mp3));

    // play() completa enseguida si ya está reproduciendo; el fin de la pista se
    // sabe por processingState.
    final finished = _player.processingStateStream.firstWhere(
      (state) =>
          state == ProcessingState.completed || state == ProcessingState.idle,
    );

    await _player.play();

    // Por si se pierde el evento de fin: como mucho, la duración más un margen.
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

// StreamAudioSource es experimental, pero es la única vía de reproducir desde memoria.
// ignore_for_file: experimental_member_use

/// Fuente de audio en memoria: just_audio exige un [StreamAudioSource].
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
