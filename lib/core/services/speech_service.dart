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
/// (el que el mayor eligió en Ajustes, ADR-0036), no el criterio del sistema.
/// Vencido ese plazo, el turno se cierra solo y avisa por `onFinal`: el mayor
/// no tiene que pulsar nada para que le contesten, que es como funciona una
/// conversación.
///
/// **La última palabra solo llega en el resultado final.** Los parciales van
/// por detrás de la voz, y Android anuncia que ha dejado de grabar
/// (`notListening`) *antes* de entregar ese final. Por eso una sesión no se da
/// por terminada cuando se apaga el micrófono, sino cuando llega el final, el
/// `done` que lo sigue o un error; y cerrar el turno también espera a ese final
/// ([kSpeechFinalResultWait] como tope). Tomar el `notListening` como cierre
/// era justo lo que perdía la última palabra de cada frase (ADR-0036).
///
/// Coste conocido: entre una sesión nativa y la siguiente hay un hueco en el
/// que no se graba: lo que tarde el final más [kSpeechResumeDelay]. Una palabra
/// arrancada justo en ese instante puede perderse. Es inherente a reanudar el
/// reconocedor y no se puede evitar sin capturar el audio por nuestra cuenta.
class SpeechService {
  SpeechService({
    stt.SpeechToText? speechToText,
    Duration leadInTimeout = kSpeechLeadInTimeout,
    Duration resumeDelay = kSpeechResumeDelay,
    Duration finalResultWait = kSpeechFinalResultWait,
  })  : _speech = speechToText ?? stt.SpeechToText(),
        _leadInTimeout = leadInTimeout,
        _resumeDelay = resumeDelay,
        _finalResultWait = finalResultWait;

  final stt.SpeechToText _speech;
  final Duration _leadInTimeout;
  final Duration _resumeDelay;
  final Duration _finalResultWait;

  /// Silencio que cierra el turno en curso. Lo trae cada [beginListening]
  /// porque es una preferencia del mayor y puede cambiar entre turnos.
  Duration _silenceTimeout = Duration.zero;

  /// Lo dicho en sesiones nativas ya cerradas de este mismo turno.
  String _committed = '';

  /// Lo dicho en la sesión nativa en curso. Cada `listen()` reinicia
  /// `recognizedWords` desde cero, así que sin estos dos campos el texto
  /// anterior desaparecería en cada reanudación.
  String _current = '';

  Timer? _silenceTimer;
  Timer? _resumeTimer;

  /// Tope de espera del resultado final de la sesión en curso (ver
  /// [kSpeechFinalResultWait]). Vencido, la sesión se da por terminada con lo
  /// que haya.
  Timer? _sessionEndTimer;

  bool _turnActive = false;

  /// El turno ya está decidido —por silencio o con el botón— y solo falta que
  /// el reconocedor entregue lo último que oyó. Ya no se reanuda nada.
  bool _closing = false;

  /// Si la sesión nativa en curso sigue admitiendo resultados.
  ///
  /// Sin esto se duplicaba lo dicho (ADR-0022): un resultado tardío de una
  /// sesión ya consolidada volvía a rellenar `_current` con las MISMAS
  /// palabras, y "hola qué tal" se convertía en "hola qué tal hola qué tal".
  /// Cerrada la sesión, sus resultados se ignoran hasta que se abra la
  /// siguiente. Lo que ha cambiado (ADR-0036) es **cuándo** se cierra: con el
  /// resultado final y no con el `notListening` que lo precede, porque ese
  /// final es el que trae la última palabra.
  bool _sessionOpen = false;

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
  /// pintarlo. [onFinal] se invoca **una sola vez**, cuando se cierra el turno
  /// —por [silenceTimeout] sin palabras nuevas o con [finishListening]—;
  /// puede llegar con texto vacío si el mayor no llegó a hablar.
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
    required Duration silenceTimeout,
  }) {
    _cancelTimers();
    _committed = '';
    _current = '';
    _resumeFailures = 0;
    _sessionOpen = false;
    _closing = false;
    _turnActive = true;
    _silenceTimeout = silenceTimeout;
    _onPartial = onPartial;
    _onFinal = onFinal;

    _startNativeSession();
    _restartSilenceTimer();
  }

  /// Cierra el turno ya, sin esperar al silencio: el mayor ha pulsado el
  /// botón. Como el cierre por silencio, espera a que el reconocedor entregue
  /// lo último que oyó —casi siempre, la última palabra— y avisa por
  /// `onFinal`.
  ///
  /// Devuelve false si no había turno abierto (ya lo cerró el silencio, o lo
  /// canceló otra pantalla): entonces no llegará ningún `onFinal`.
  bool finishListening() {
    if (!_turnActive) return false;
    _finishTurn();
    return true;
  }

  /// Aborta el turno descartando lo reconocido. Para cuando la escucha deja de
  /// tener sentido (se abre la pantalla de emergencia, se destruye el chat).
  /// No avisa por `onFinal`.
  void cancelListening() {
    _closeTurn();
    _speech.cancel();
    _committed = '';
    _current = '';
  }

  // ── Interno ────────────────────────────────────────────────────────────

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _sessionEndTimer?.cancel();
    _sessionEndTimer = null;
  }

  void _closeTurn() {
    _turnActive = false;
    _closing = false;
    _sessionOpen = false;
    _cancelTimers();
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
      if (!_turnActive) {
        // El turno se cerró mientras el reconocedor arrancaba: nadie va a
        // recoger lo que oiga, y es el micrófono del mayor.
        _speech.cancel();
        return;
      }
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

    final words = result.recognizedWords;
    // Solo el habla nueva reinicia el plazo. Un resultado vacío es ruido, y
    // un final que repite el último parcial no es habla: dejar que cualquiera
    // de los dos reiniciara el contador alargaría la espera sin motivo.
    final heardMore = words.isNotEmpty && words != _current;
    // Un final vacío no borra lo que los parciales ya habían oído.
    if (words.isNotEmpty) _current = words;

    _onPartial?.call(transcript);
    if (heardMore && !_closing) _restartSilenceTimer();

    // El sistema cierra la frase: es el texto definitivo de esta sesión.
    if (result.finalResult) _endSession();
  }

  void _handleStatus(String status) {
    if (!_turnActive) return;
    if (status == stt.SpeechToText.doneStatus) {
      // El paquete solo deja pasar `done` cuando ya entregó el final, o
      // cuando la sesión no oyó nada: en ambos casos no queda nada por llegar.
      _endSession();
    } else if (status == stt.SpeechToText.notListeningStatus) {
      // El micrófono se ha apagado, pero el final —el que trae la última
      // palabra— llega DESPUÉS. Cerrar aquí la sesión lo tiraba (ADR-0036).
      _awaitSessionEnd();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!_turnActive) return;
    // Android dispara `error_no_match` y `error_speech_timeout` en cada pausa,
    // y los marca como permanentes. Para nosotros solo significan "esta sesión
    // nativa terminó": se conserva lo dicho y se reanuda.
    if (kDebugMode) debugPrint('[STT] ${error.errorMsg} — reanudando turno.');
    if (_current.isEmpty) {
      // Nada en vuelo: reanudar en el acto acorta el hueco sin micrófono.
      _endSession();
    } else {
      // Con palabras en vuelo, el error puede adelantarse al final (ADR-0022).
      _awaitSessionEnd();
    }
  }

  /// Da un tope a la llegada del resultado final de la sesión en curso.
  void _awaitSessionEnd() {
    if (!_sessionOpen || _sessionEndTimer != null) return;
    _sessionEndTimer = Timer(_finalResultWait, _endSession);
  }

  /// La sesión nativa en curso ha terminado y ya no llegará nada más de ella:
  /// se consolida lo oído y se abre la siguiente, o se termina de cerrar el
  /// turno si ya estaba decidido. Idempotente: el final, el `done` y el tope
  /// pueden llegar los tres.
  void _endSession() {
    _sessionEndTimer?.cancel();
    _sessionEndTimer = null;
    if (!_turnActive || !_sessionOpen) return;

    _sessionOpen = false;
    _commitCurrent();
    if (_closing) {
      _completeTurn();
    } else {
      _scheduleResume();
    }
  }

  void _scheduleResume() {
    if (!_turnActive || _closing || _resumeTimer != null) return;

    if (_resumeFailures >= kSpeechMaxResumeFailures) {
      // El reconocedor no vuelve. Se cierra el turno con lo que haya en vez de
      // dejar al mayor mirando un micrófono encendido que no graba.
      if (kDebugMode) debugPrint('[STT] Reanudación agotada; cierro el turno.');
      _finishTurn();
      return;
    }

    _resumeTimer = Timer(_resumeDelay, _resumeNow);
  }

  Future<void> _resumeNow() async {
    _resumeTimer = null;
    if (!_turnActive || _closing) return;

    // Cerrar antes de reabrir, siempre. Es el contrato explícito del paquete
    // ("When listening is done always invoke either cancel or stop to end the
    // session, even if it times out") y aquí importa el doble: si la sesión
    // anterior sigue viva, `isListening` se queda en true y la reanudación no
    // llegaba a ocurrir — el micrófono se quedaba encendido sin transcribir.
    await _speech.stop();
    if (!_turnActive || _closing) return;
    await _startNativeSession();
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    // Antes de la primera palabra se concede mucho más margen: el plazo corto
    // mide pausas entre frases, no el tiempo que cuesta arrancar. Nunca menos
    // que la pausa elegida: quien pide que se le espere diez segundos no
    // tiene que arrancar en ocho.
    final timeout = transcript.isEmpty
        ? (_leadInTimeout > _silenceTimeout ? _leadInTimeout : _silenceTimeout)
        : _silenceTimeout;
    _silenceTimer = Timer(timeout, _finishTurn);
  }

  /// Decide el fin del turno —por silencio, con el botón o porque el
  /// reconocedor no vuelve— y espera, si hace falta, a lo último que oyó.
  void _finishTurn() {
    if (!_turnActive || _closing) return;
    _closing = true;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;

    if (!_sessionOpen) {
      // Entre dos sesiones: no hay nada en vuelo.
      _completeTurn();
      return;
    }
    // `stop()`, no `cancel()`: pide al reconocedor que entregue el final.
    _speech.stop();
    _awaitSessionEnd();
  }

  /// Cierra el turno y avisa. Es el único camino hacia `onFinal`.
  void _completeTurn() {
    if (!_turnActive) return;

    final onFinal = _onFinal;
    _closeTurn();

    final text = transcript.trim();
    if (kDebugMode) debugPrint('[STT] Turno cerrado: "$text"');
    onFinal?.call(text);
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
