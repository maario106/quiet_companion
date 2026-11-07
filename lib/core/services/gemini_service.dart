import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/conversation_config.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';

/// Result of a single Gemini turn.
///
/// [text] is the text reply to speak/display.
class GeminiResponse {
  final String? text;

  /// La respuesta es un mensaje de error de la app, no del modelo. No es
  /// conversación: no entra en el búfer que se analiza al cerrar (ADR-0028).
  final bool failed;

  const GeminiResponse({this.text, this.failed = false});
}

/// El chat con el mayor, a través de la callable `chatTurn` (ADR-0014).
///
/// El servidor llama a Gemini con sus propias credenciales: la app no lleva
/// ninguna clave. También pone allí el prompt, el nombre y la memoria del
/// mayor, y guarda el nombre cuando el modelo llama a `guardarNombre`; aquí
/// solo viajan el mensaje y los turnos de la conversación en curso.
class GeminiService {
  GeminiService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  /// Lo que se espera antes de dar el turno por fallido. Con `guardarNombre`
  /// son dos llamadas al modelo.
  static const Duration _timeout = Duration(seconds: 30);

  /// Envía lo que ha dicho el mayor con [history], los turnos anteriores de
  /// esta conversación, y devuelve la respuesta del modelo. Nunca lanza: un
  /// fallo vuelve como respuesta con [GeminiResponse.failed].
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
        // El servidor corre en UTC: con esto dice "ayer a las 18:30" en la
        // hora del teléfono al recordar conversaciones anteriores.
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });

      // El canal de plataforma entrega mapas sin tipar; se lee
      // defensivamente en vez de castear, que falla en Android.
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
