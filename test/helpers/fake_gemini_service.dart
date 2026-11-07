import 'dart:async';

import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';

/// Doble de [GeminiService]: responde "Respuesta a: …" sin red y guarda lo
/// que recibe.
class FakeGeminiService implements GeminiService {
  bool failNext = false;
  List<ConversationTurn> lastHistory = const [];
  final sent = <String>[];

  /// Si no es `null`, la respuesta espera a que el test lo complete: así se
  /// puede mirar el controlador con un turno en vuelo.
  Completer<void>? gate;

  @override
  Future<GeminiResponse> sendMessage(
    String text, {
    List<ConversationTurn> history = const [],
  }) async {
    sent.add(text);
    lastHistory = history;
    final pending = gate;
    if (pending != null) await pending.future;
    if (failNext) {
      failNext = false;
      return const GeminiResponse(text: 'Upss…', failed: true);
    }
    return GeminiResponse(text: 'Respuesta a: $text');
  }
}
