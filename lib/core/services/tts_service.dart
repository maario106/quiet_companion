import 'package:quiet_companion/core/models/user_preferences.dart';

/// Síntesis de voz: nube ([CloudTtsService]) con respaldo ([DeviceTtsService]).
abstract interface class TtsService {
  /// Dice [text] y completa cuando termina de sonar. Interrumpe lo que esté
  /// sonando y nunca lanza.
  Future<void> speak(String text);

  /// Corta la reproducción y descarta la síntesis en vuelo. Idempotente.
  Future<void> stop();

  /// Aplica las preferencias de voz del mayor.
  Future<void> applyPreferences(UserPreferences prefs);

  /// Si hay una locución sonando o sintetizándose.
  bool get isSpeaking;

  /// Libera los recursos de audio.
  Future<void> dispose();
}
