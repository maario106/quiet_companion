import 'package:quiet_companion/core/services/speech_service.dart';

/// Doble de [SpeechService]: el micrófono siempre está disponible y solo oye
/// lo que el test le hace decir con [deliverFinal].
class FakeSpeechService implements SpeechService {
  int cancelCalls = 0;
  int finishCalls = 0;

  /// Pausa con la que se abrió el último turno.
  Duration? lastSilenceTimeout;

  void Function(String transcript)? _onFinal;

  @override
  Future<bool> initiate() async => true;

  @override
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
    required Duration silenceTimeout,
  }) {
    lastSilenceTimeout = silenceTimeout;
    _onFinal = onFinal;
  }

  /// Como el servicio real, no envía en el acto: el turno se cierra cuando el
  /// test entrega el final con [deliverFinal].
  @override
  bool finishListening() {
    finishCalls++;
    return _onFinal != null;
  }

  /// Cierra el turno abierto con [text], como haría el reconocedor.
  void deliverFinal(String text) {
    final onFinal = _onFinal;
    _onFinal = null;
    onFinal?.call(text);
  }

  @override
  void cancelListening() {
    cancelCalls++;
    _onFinal = null;
  }

  @override
  String get transcript => '';

  @override
  bool get isListening => false;
}
