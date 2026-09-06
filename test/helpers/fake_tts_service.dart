import 'dart:async';

import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/services/tts_service.dart';

/// Doble de [TtsService] compartido por los tests. Registra lo que se dice y
/// permite controlar cuándo termina una locución, para poder simular
/// interrupciones y locuciones largas sin esperas reales.
class FakeTtsService implements TtsService {
  final List<String> spoken = [];
  int stopCalls = 0;
  int disposeCalls = 0;
  UserPreferences? appliedPreferences;

  /// Con `true`, [speak] no completa hasta llamar a [finishSpeaking]: así el
  /// test puede interrumpir a mitad de locución.
  bool blockUntilFinished = false;

  Completer<void>? _pending;
  bool _speaking = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    if (!blockUntilFinished) return;

    _speaking = true;
    _pending = Completer<void>();
    await _pending!.future;
    _speaking = false;
  }

  /// Termina la locución bloqueada en curso, si la hay.
  void finishSpeaking() {
    if (_pending?.isCompleted == false) _pending!.complete();
    _pending = null;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    finishSpeaking();
    _speaking = false;
  }

  @override
  Future<void> applyPreferences(UserPreferences prefs) async {
    appliedPreferences = prefs;
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    finishSpeaking();
  }
}
