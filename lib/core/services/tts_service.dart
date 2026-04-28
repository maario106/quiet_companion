import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  // Aplica las preferencias del usuario en caliente. flutter_tts solo permite
  // que volumen y velocidad afecten a la *siguiente* locución, no a la actual,
  // así que no intentamos interrumpir la voz en curso.
  Future<void> applyPreferences(UserPreferences prefs) async {
    await _flutterTts.setVolume(prefs.volume);
    await _flutterTts.setSpeechRate(prefs.speechRate);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // flutter_tts no expone un dispose explícito; stop() libera recursos de la
  // sesión de audio y es la equivalencia segura.
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}

// Provider del [TtsService]. Escucha [currentUserProvider] y aplica las
// preferencias del usuario (volumen, velocidad) cada vez que cambian en
// Firestore. Mantiene el servicio sin estado sobre las preferencias: es el
// provider quien orquesta la propagación.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();

  ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
    final prefs = next.valueOrNull?.preferences;
    if (prefs == null) return;
    service.applyPreferences(prefs);
  });

  // dispose() es Future<void>; envolverlo en una closure deja explícito que es
  // fire-and-forget (el callback de onDispose es void Function()).
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
