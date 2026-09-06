import 'package:flutter/foundation.dart';
import 'package:quiet_companion/core/config/tts_config.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/tts_audio_player.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'package:quiet_companion/core/services/tts_synthesizer.dart';
import 'package:quiet_companion/core/utils/sentence_splitter.dart';

/// Velocidad de reproductor equivalente a la preferencia [speechRate].
///
/// Función pura y pública: es la traducción entre la escala del deslizador
/// del familiar (la de `flutter_tts`) y la del reproductor, y el único punto
/// donde esa equivalencia se decide (ADR-0019).
double playerSpeedFor(double speechRate) =>
    (speechRate * kTtsRateToPlayerSpeed)
        .clamp(kTtsMinPlayerSpeed, kTtsMaxPlayerSpeed);

/// Voz de nube (Chirp 3: HD) con respaldo automático al motor del
/// dispositivo. Implementación de producción de [TtsService].
///
/// La locución se trocea en frases y se reproduce en orden mientras se
/// sintetiza la siguiente: el mayor empieza a oír la respuesta tras un solo
/// viaje de red, no tras el de la respuesta entera.
///
/// Nunca reintenta (ADR-0017). Un fallo o un timeout se resuelve hablando con
/// la voz del dispositivo, que es peor pero inmediata; un silencio de varios
/// segundos sería ininterpretable para esta población.
class CloudTtsService implements TtsService {
  CloudTtsService({
    required TtsSynthesizer synthesizer,
    required TtsAudioPlayer player,
    required TtsService fallback,
    Duration chunkTimeout = kTtsChunkTimeout,
  })  : _synthesizer = synthesizer,
        _player = player,
        _fallback = fallback,
        _chunkTimeout = chunkTimeout;

  final TtsSynthesizer _synthesizer;
  final TtsAudioPlayer _player;
  final TtsService _fallback;

  /// Inyectable solo para que los tests no esperen segundos reales; en la app
  /// siempre vale [kTtsChunkTimeout].
  final Duration _chunkTimeout;

  /// Identifica la locución en curso. Las callables no se pueden abortar, así
  /// que la cancelación consiste en invalidar la generación: cualquier audio
  /// que llegue con una generación vieja se tira.
  int _generation = 0;
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> speak(String text) async {
    // Hablar mientras se habla interrumpe: nunca dos voces a la vez.
    await stop();
    final generation = _generation;

    final spoken = sanitizeForSpeech(text);
    final chunks = splitIntoSentences(spoken);
    if (chunks.isEmpty) return;

    _speaking = true;
    try {
      // Prefetch de exactamente uno: se sintetiza el siguiente fragmento
      // mientras suena el actual. Lanzarlos todos a la vez multiplicaría el
      // coste y el ancho de banda por una respuesta que puede cortarse.
      var pending = _synthesize(chunks.first, generation);

      for (var i = 0; i < chunks.length; i++) {
        final audio = await pending;
        if (generation != _generation) return; // Interrumpida mientras venía.

        if (audio != null) {
          pending = i + 1 < chunks.length
              ? _synthesize(chunks[i + 1], generation)
              : Future<Uint8List?>.value();

          if (await _play(audio)) continue;
          if (generation != _generation) return; // Interrumpida al reproducir.
        }

        // Este fragmento no se ha oído: o no se sintetizó, o no sonó. Primer
        // fragmento: se repite la locución entera con la voz del dispositivo.
        // Fragmento posterior: solo lo que falta, sin repetir lo ya escuchado.
        if (kDebugMode) {
          debugPrint('[TTS] Respaldo al dispositivo en el fragmento $i.');
        }
        await _fallback.speak(i == 0 ? spoken : chunks.sublist(i).join(' '));
        return;
      }
    } finally {
      // Si otra locución tomó el relevo, el estado ya es suyo.
      if (generation == _generation) _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _speaking = false;
    await _player.stop();
    // El respaldo puede ser quien esté hablando en este momento.
    await _fallback.stop();
  }

  @override
  Future<void> applyPreferences(UserPreferences prefs) async {
    // La voz se sintetiza siempre a ritmo neutro; la preferencia del mayor se
    // aplica en la reproducción. Así el cliente no envía parámetros de voz al
    // servidor y el deslizador del familiar sigue significando lo mismo en
    // ambas voces.
    await _player.setSpeed(playerSpeedFor(prefs.speechRate));
    await _player.setVolume(prefs.volume);
    await _fallback.applyPreferences(prefs);
  }

  @override
  Future<void> dispose() async {
    _generation++;
    _speaking = false;
    await _player.dispose();
    await _fallback.dispose();
  }

  /// Reproduce un fragmento. Devuelve false si el reproductor falla — una
  /// interrupción a mitad de `setAudioSource` o un MP3 que no decodifica no
  /// pueden salir como excepción hacia el flujo de conversación, que las
  /// mostraría al mayor como un error de conexión.
  Future<bool> _play(Uint8List audio) async {
    try {
      await _player.play(audio);
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('[TTS] Reproducción fallida: $error');
      return false;
    }
  }

  /// Sintetiza un fragmento. Devuelve null si falla, vence el plazo o la
  /// locución ya ha sido cancelada: el llamante trata los tres casos igual.
  Future<Uint8List?> _synthesize(String chunk, int generation) async {
    try {
      final audio =
          await _synthesizer.synthesize(chunk).timeout(_chunkTimeout);
      return generation == _generation ? audio : null;
    } catch (error) {
      if (kDebugMode) debugPrint('[TTS] Síntesis fallida: $error');
      return null;
    }
  }
}
