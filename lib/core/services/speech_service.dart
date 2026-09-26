import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/speech_config.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Escucha del mayor como **un turno**, no como una sesión del reconocedor.
///
/// El reconocedor de Android no dura lo que dura una intervención: corta por su
/// cuenta tras uno a tres segundos de silencio ("a system imposed pause ... that
/// cannot be overridden", documentación de `speech_to_text`) y avisa con un
/// resultado final, un cambio de estado o un `error_no_match`. Antes, cualquiera
/// de las tres cosas terminaba la escucha: el mayor hacía una pausa a media
/// frase, el micrófono se apagaba en silencio y lo que dijera después se perdía.
///
/// Aquí la sesión nativa es desechable. Cuando se acaba, se abre otra y el texto
/// se acumula; lo que decide el fin del turno es **el silencio medido aquí**
/// ([kSpeechSilenceTimeout]), no el criterio del sistema. Vencido ese plazo, el
/// turno se cierra solo y avisa por [onFinal]: el mayor no tiene que pulsar nada
/// para que le contesten, que es como funciona una conversación.
///
/// Coste conocido: entre una sesión nativa y la siguiente hay un hueco de
/// [kSpeechResumeDelay] en el que no se graba. Una palabra arrancada justo en
/// ese instante puede perderse. Es inherente a reanudar el reconocedor y no se
/// puede evitar sin capturar el audio por nuestra cuenta.
class SpeechService {
  SpeechService({
    stt.SpeechToText? speechToText,
    Duration silenceTimeout = kSpeechSilenceTimeout,
    Duration leadInTimeout = kSpeechLeadInTimeout,
    Duration resumeDelay = kSpeechResumeDelay,
  })  : _speech = speechToText ?? stt.SpeechToText(),
        _silenceTimeout = silenceTimeout,
        _leadInTimeout = leadInTimeout,
        _resumeDelay = resumeDelay;

  final stt.SpeechToText _speech;
  final Duration _silenceTimeout;
  final Duration _leadInTimeout;
  final Duration _resumeDelay;

  /// Lo dicho en sesiones nativas ya cerradas de este mismo turno.
  String _committed = '';

  /// Lo dicho en la sesión nativa en curso. Cada `listen()` reinicia
  /// `recognizedWords` desde cero, así que sin estos dos campos el texto
  /// anterior desaparecería en cada reanudación.
  String _current = '';

  Timer? _silenceTimer;
  bool _turnActive = false;

  /// Si la sesión nativa en curso sigue admitiendo resultados.
  ///
  /// Sin esto se duplicaba lo dicho. El reconocedor no ordena sus avisos: el
  /// `error_no_match` de la pausa puede llegar ANTES del resultado final, y el
  /// paquete además sintetiza un final propio pasado `finalTimeout` (lo arma
  /// `stop()`). Cada uno de esos avisos consolidaba el texto, y el siguiente
  /// volvía a rellenar `_current` con las MISMAS palabras: "hola qué tal" se
  /// convertía en "hola qué tal hola qué tal". Cerrada la sesión, sus
  /// resultados tardíos se ignoran hasta que se abra la siguiente.
  bool _sessionOpen = false;

  bool _resumeScheduled = false;
  int _resumeFailures = 0;

  void Function(String transcript)? _onPartial;
  void Function(String transcript)? _onFinal;

  bool get isListening => _speech.isListening;

  /// Texto del turno completo: lo cerrado más lo que se está oyendo ahora.
  String get transcript {
    if (_current.isEmpty) return _committed;
    if (_committed.isEmpty) return _current;
    return '$_committed $_current';
  }

  Future<bool> initiate() async {
    return _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );
  }

  /// Abre un turno de escucha.
  ///
  /// [onPartial] recibe el texto acumulado a medida que se reconoce, para
  /// pintarlo. [onFinal] se invoca **una sola vez**, cuando el silencio cierra
  /// el turno; puede llegar con texto vacío si el mayor no llegó a hablar.
  /// Un cierre manual con [stopListening] no dispara [onFinal]: quien pulsa el
  /// botón ya sabe que ha terminado.
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
  }) {
    _committed = '';
    _current = '';
    _resumeFailures = 0;
    _resumeScheduled = false;
    _sessionOpen = false;
    _turnActive = true;
    _onPartial = onPartial;
    _onFinal = onFinal;

    _startNativeSession();
    _restartSilenceTimer();
  }

  /// Cierra el turno por decisión del usuario y devuelve lo reconocido.
  /// Idempotente.
  String stopListening() {
    _closeTurn();
    _speech.stop();
    return transcript.trim();
  }

  /// Aborta el turno descartando lo reconocido. Para cuando la escucha deja de
  /// tener sentido (se abre la pantalla de emergencia, se destruye el chat).
  void cancelListening() {
    _closeTurn();
    _speech.cancel();
    _committed = '';
    _current = '';
  }

  // ── Interno ────────────────────────────────────────────────────────────

  void _closeTurn() {
    _turnActive = false;
    _sessionOpen = false;
    _resumeScheduled = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _commitCurrent();
    _onPartial = null;
    _onFinal = null;
  }

  void _commitCurrent() {
    if (_current.isEmpty) return;
    _committed = _committed.isEmpty ? _current : '$_committed $_current';
    _current = '';
  }

  Future<void> _startNativeSession() async {
    try {
      await _speech.listen(
        onResult: _handleResult,
        localeId: kSpeechLocaleId,
        listenFor: kSpeechMaxNativeSession,
        // `pauseFor` a propósito sin usar: delegaría en el paquete el criterio
        // de fin de turno, y aquí una pausa NO termina el turno — reanuda la
        // sesión. La pausa que cuenta la mide _silenceTimer.
        listenOptions: stt.SpeechListenOptions(
          // false, no true: `cancel()` descarta lo reconocido y `stop()` lo
          // conserva. Con true, un `error_no_match` —que Android dispara en
          // cada pausa— tiraba a la basura lo que el mayor llevaba dicho.
          cancelOnError: false,
          partialResults: true,
          // Solo tiene efecto en iOS según el paquete; en Android es inerte.
          // Se deja porque es correcto donde sí se aplica, pero no es lo que
          // mantiene viva la escucha aquí.
          listenMode: stt.ListenMode.dictation,
        ),
      );
      _sessionOpen = true;
      _resumeFailures = 0;
    } catch (error) {
      _resumeFailures++;
      if (kDebugMode) {
        debugPrint('[STT] No se pudo abrir la sesión ($_resumeFailures): $error');
      }
      _scheduleResume();
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    // `_sessionOpen`, no solo `_turnActive`: un resultado de una sesión ya
    // consolidada repetiría texto (ver el campo).
    if (!_turnActive || !_sessionOpen) return;

    _current = result.recognizedWords;
    if (result.finalResult) {
      // El sistema cierra la frase: se consolida, se da la sesión por
      // terminada y se espera a la siguiente, que contará desde cero.
      _commitCurrent();
      _sessionOpen = false;
    }

    _onPartial?.call(transcript);

    // Solo el habla reinicia el plazo. Un resultado vacío es ruido, y dejarlo
    // reiniciar el contador mantendría el turno abierto para siempre.
    if (result.recognizedWords.isNotEmpty) _restartSilenceTimer();
  }

  void _handleStatus(String status) {
    if (!_turnActive) return;
    if (status == stt.SpeechToText.doneStatus ||
        status == stt.SpeechToText.notListeningStatus) {
      // Fin de la sesión nativa, no del turno: Android la cierra sola mucho
      // antes de la pausa que damos por buena.
      _commitCurrent();
      _sessionOpen = false;
      _scheduleResume();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!_turnActive) return;
    // Android dispara `error_no_match` y `error_speech_timeout` en cada pausa,
    // y los marca como permanentes. Para nosotros solo significan "esta sesión
    // nativa terminó": se conserva lo dicho y se reanuda.
    if (kDebugMode) debugPrint('[STT] ${error.errorMsg} — reanudando turno.');
    _commitCurrent();
    _sessionOpen = false;
    _scheduleResume();
  }

  void _scheduleResume() {
    if (!_turnActive || _resumeScheduled) return;

    if (_resumeFailures >= kSpeechMaxResumeFailures) {
      // El reconocedor no vuelve. Se cierra el turno con lo que haya en vez de
      // dejar al mayor mirando un micrófono encendido que no graba.
      if (kDebugMode) debugPrint('[STT] Reanudación agotada; cierro el turno.');
      _finishTurn();
      return;
    }

    _resumeScheduled = true;
    Timer(_resumeDelay, _resumeNow);
  }

  Future<void> _resumeNow() async {
    _resumeScheduled = false;
    if (!_turnActive) return;

    // Cerrar antes de reabrir, siempre. Es el contrato explícito del paquete
    // ("When listening is done always invoke either cancel or stop to end the
    // session, even if it times out") y aquí importa el doble: si la sesión
    // anterior sigue viva, `isListening` se queda en true y la reanudación no
    // llegaba a ocurrir — el micrófono se quedaba encendido sin transcribir.
    await _speech.stop();
    if (!_turnActive) return;
    await _startNativeSession();
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    // Antes de la primera palabra se concede mucho más margen: el plazo corto
    // mide pausas entre frases, no el tiempo que cuesta arrancar.
    final timeout = transcript.isEmpty ? _leadInTimeout : _silenceTimeout;
    _silenceTimer = Timer(timeout, _finishTurn);
  }

  /// Cierra el turno por silencio y avisa. Es el único camino hacia [onFinal].
  void _finishTurn() {
    if (!_turnActive) return;

    final onFinal = _onFinal;
    _closeTurn();
    _speech.stop();

    final text = transcript.trim();
    if (kDebugMode) {
      debugPrint('[STT] Turno cerrado por silencio: "${text.isEmpty ? '' : text}"');
    }
    onFinal?.call(text);
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
