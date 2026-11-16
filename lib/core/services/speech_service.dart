import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/speech_config.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Escucha del mayor como un turno: encadena sesiones nativas (Android corta en
/// cada pausa) y lo cierra el silencio elegido en Ajustes o el botón.
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

  /// Silencio que cierra el turno; llega con cada [beginListening].
  Duration _silenceTimeout = Duration.zero;

  /// Lo dicho en sesiones nativas ya cerradas de este mismo turno.
  String _committed = '';

  /// Lo dicho en la sesión nativa en curso; cada listen() empieza de cero.
  String _current = '';

  Timer? _silenceTimer;
  Timer? _resumeTimer;

  /// Tope de espera del resultado final de la sesión en curso.
  Timer? _sessionEndTimer;

  bool _turnActive = false;

  /// El turno ya está decidido y solo falta el último resultado; no se reanuda.
  bool _closing = false;

  /// Si la sesión en curso admite resultados. Los tardíos de una sesión cerrada
  /// duplicarían el texto.
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

  /// Abre un turno. [onFinal] llega una sola vez al cerrarse, con texto vacío si
  /// el mayor no habló.
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

  /// Cierra el turno sin esperar al silencio. False si no había turno abierto.
  bool finishListening() {
    if (!_turnActive) return false;
    _finishTurn();
    return true;
  }

  /// Aborta el turno sin avisar por onFinal.
  void cancelListening() {
    _closeTurn();
    _speech.cancel();
    _committed = '';
    _current = '';
  }

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
        // Sin pauseFor: una pausa reanuda la sesión; el fin del turno lo mide _silenceTimer.
        listenOptions: stt.SpeechListenOptions(
          // Con true, el error_no_match de cada pausa descartaría lo dicho.
          cancelOnError: false,
          partialResults: true,
          // Solo tiene efecto en iOS.
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (!_turnActive) {
        // El turno se cerró mientras arrancaba: se suelta el micrófono.
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
    // Un resultado de una sesión ya cerrada repetiría texto.
    if (!_turnActive || !_sessionOpen) return;

    final words = result.recognizedWords;
    // Solo el habla nueva reinicia el plazo.
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
      // done llega tras el final o si no se oyó nada.
      _endSession();
    } else if (status == stt.SpeechToText.notListeningStatus) {
      // El final, con la última palabra, llega después de apagarse el micrófono.
      _awaitSessionEnd();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!_turnActive) return;
    // Android da error_no_match y error_speech_timeout en cada pausa: se reanuda.
    if (kDebugMode) debugPrint('[STT] ${error.errorMsg} — reanudando turno.');
    if (_current.isEmpty) {
      // Nada en vuelo: reanudar en el acto acorta el hueco sin micrófono.
      _endSession();
    } else {
      // Con palabras en vuelo, el error puede adelantarse al final.
      _awaitSessionEnd();
    }
  }

  /// Da un tope a la llegada del resultado final de la sesión en curso.
  void _awaitSessionEnd() {
    if (!_sessionOpen || _sessionEndTimer != null) return;
    _sessionEndTimer = Timer(_finalResultWait, _endSession);
  }

  /// Consolida lo oído y abre la siguiente sesión, o cierra el turno. Idempotente.
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
      // El reconocedor no vuelve: se cierra el turno con lo que haya.
      if (kDebugMode) debugPrint('[STT] Reanudación agotada; cierro el turno.');
      _finishTurn();
      return;
    }

    _resumeTimer = Timer(_resumeDelay, _resumeNow);
  }

  Future<void> _resumeNow() async {
    _resumeTimer = null;
    if (!_turnActive || _closing) return;

    // Cerrar antes de reabrir, siempre; si no, isListening se queda en true.
    await _speech.stop();
    if (!_turnActive || _closing) return;
    await _startNativeSession();
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    // Antes de la primera palabra hay más margen, nunca menos que la pausa elegida.
    final timeout = transcript.isEmpty
        ? (_leadInTimeout > _silenceTimeout ? _leadInTimeout : _silenceTimeout)
        : _silenceTimeout;
    _silenceTimer = Timer(timeout, _finishTurn);
  }

  /// Decide el fin del turno y espera, si hace falta, al último resultado.
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
