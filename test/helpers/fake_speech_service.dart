import 'package:quiet_companion/core/services/speech_service.dart';

/// Doble de [SpeechService]: el micrófono siempre está disponible y nunca oye
/// nada.
class FakeSpeechService implements SpeechService {
  int cancelCalls = 0;

  @override
  Future<bool> initiate() async => true;

  @override
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
  }) {}

  @override
  String stopListening() => '';

  @override
  void cancelListening() => cancelCalls++;

  @override
  String get transcript => '';

  @override
  bool get isListening => false;
}
