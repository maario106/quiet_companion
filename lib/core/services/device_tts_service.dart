import 'package:flutter_tts/flutter_tts.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/tts_service.dart';

/// Voz del motor TTS del dispositivo: respaldo de [CloudTtsService] y voz sin conexión.
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
    // speak() espera a que acabe la voz antes de volver.
    await _flutterTts.awaitSpeakCompletion(true);
  }

  // flutter_tts aplica volumen y velocidad a partir de la siguiente locución.
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

  // flutter_tts no tiene dispose; stop() libera la sesión de audio.
  @override
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
