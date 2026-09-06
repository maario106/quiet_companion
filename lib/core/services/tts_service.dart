import 'package:quiet_companion/core/models/user_preferences.dart';

/// Borde de plataforma de la síntesis de voz. Hermano de
/// [EmergencyCallService]: interfaz + implementación de producción
/// ([CloudTtsService]) + respaldo ([DeviceTtsService]) + fake para tests.
///
/// El flujo conversacional habla contra esta interfaz y no sabe si la voz
/// viene de la nube o del motor del dispositivo (ADR-0017).
abstract interface class TtsService {
  /// Dice [text] en voz alta. Trocea internamente en frases, las sintetiza y
  /// las reproduce en orden. Completa cuando ha terminado de sonar la última
  /// (o antes, si [stop] la interrumpe).
  ///
  /// Es seguro llamarlo mientras ya se está hablando: la locución en curso se
  /// detiene primero. Nunca lanza: un fallo de red acaba en la voz del
  /// dispositivo, no en una excepción — el turno de conversación de un mayor
  /// no puede romperse por un timeout.
  Future<void> speak(String text);

  /// Corta la reproducción, descarta la síntesis en vuelo y vacía la cola.
  /// Idempotente, y deja el servicio listo para el siguiente [speak].
  Future<void> stop();

  /// Aplica volumen y velocidad del mayor. La invoca el provider cuando
  /// cambian en Firestore, no el flujo de conversación.
  Future<void> applyPreferences(UserPreferences prefs);

  /// Si hay una locución sonando o sintetizándose.
  bool get isSpeaking;

  /// Libera los recursos de audio.
  Future<void> dispose();
}
