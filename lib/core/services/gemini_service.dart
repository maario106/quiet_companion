import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/conversation_config.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';

/// Resultado de un turno de Gemini.
class GeminiResponse {
  final String? text;

  /// Mensaje de error de la app, no del modelo; no entra en lo que se analiza.
  final bool failed;

  const GeminiResponse({this.text, this.failed = false});
}

/// Chat con el mayor a través de la callable chatTurn. Prompt, nombre y memoria
/// los pone el servidor; aquí solo viajan el mensaje y los turnos en curso.
class GeminiService {
  GeminiService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  /// Con guardarNombre son dos llamadas al modelo.
  static const Duration _timeout = Duration(seconds: 30);

  /// Envía el mensaje con [history] y devuelve la respuesta. Nunca lanza: un
  /// fallo vuelve con [GeminiResponse.failed].
  Future<GeminiResponse> sendMessage(
    String text, {
    List<ConversationTurn> history = const [],
  }) async {
    final recent = history.length > kChatHistoryMaxTurns
        ? history.sublist(history.length - kChatHistoryMaxTurns)
        : history;

    try {
      final result = await _functions
          .httpsCallable(
            kChatTurnCallable,
            options: HttpsCallableOptions(timeout: _timeout),
          )
          .call<dynamic>(<String, dynamic>{
        'message': text,
        'history': [
          for (final turn in recent) {'role': turn.role.name, 'text': turn.text},
        ],
        // Para decir las fechas en la hora del teléfono.
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });

      // El canal de plataforma entrega mapas sin tipar.
      final data = result.data;
      final reply = data is Map ? data['text'] : null;
      if (reply is! String || reply.trim().isEmpty) {
        return const GeminiResponse(
          text: 'No se ha podido generar una respuesta.',
          failed: true,
        );
      }
      return GeminiResponse(text: reply);
    } catch (_) {
      return const GeminiResponse(
        text: 'Upss, ha habido un problema con la conexión. ¿Puedes repetir?',
        failed: true,
      );
    }
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
