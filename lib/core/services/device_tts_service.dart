import 'package:flutter_tts/flutter_tts.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/tts_service.dart';

/// Voz del motor TTS del dispositivo. Es la implementación histórica del
/// proyecto, ahora en dos papeles: respaldo de [CloudTtsService] cuando la
/// síntesis en nube falla o no hay red, y única voz posible sin conexión.
///
/// Sin cambios de comportamiento respecto de la versión anterior: mismo
/// idioma, mismo tono y misma advertencia sobre las preferencias.
class DeviceTtsService implements TtsService {
  DeviceTtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts() {
    _initializeTts();
  }

  final FlutterTts _flutterTts;
  bool _speaking = false;

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setPitch(1.0);
    // Sin esto, speak() volvería antes de que acabe la voz y el flujo de
    // conversación reanudaría la escucha encima de la locución.
    await _flutterTts.awaitSpeakCompletion(true);
  }

  // Aplica las preferencias del usuario en caliente. flutter_tts solo permite
  // que volumen y velocidad afecten a la *siguiente* locución, no a la actual,
  // así que no intentamos interrumpir la voz en curso.
  @override
  Future<void> applyPreferences(UserPreferences prefs) async {
    await _flutterTts.setVolume(prefs.volume);
    await _flutterTts.setSpeechRate(prefs.speechRate);
  }

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    try {
      await _flutterTts.speak(text);
    } finally {
      _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    await _flutterTts.stop();
  }

  @override
  bool get isSpeaking => _speaking;

  // flutter_tts no expone un dispose explícito; stop() libera recursos de la
  // sesión de audio y es la equivalencia segura.
  @override
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
