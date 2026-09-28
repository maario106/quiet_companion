import 'package:cloud_functions/cloud_functions.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';

/// Entrega la conversación terminada a la callable `closeConversation`
/// (ADR-0029). La transcripción viaja en la petición y el servidor la
/// descarta tras analizarla: no se escribe en ningún sitio.
class CloudConversationCloser implements ConversationCloser {
  const CloudConversationCloser(this._functions);

  final FirebaseFunctions _functions;

  /// El análisis tarda más que una síntesis de voz: una llamada a Gemini con
  /// la conversación entera.
  static const Duration _timeout = Duration(seconds: 60);

  @override
  Future<void> close(ClosedConversation conversation) async {
    final turns = conversation.turns;
    await _functions
        .httpsCallable(
          kCloseConversationCallable,
          options: HttpsCallableOptions(timeout: _timeout),
        )
        .call<dynamic>(<String, dynamic>{
      'startedAt': conversation.startedAt.millisecondsSinceEpoch,
      'endedAt': conversation.endedAt.millisecondsSinceEpoch,
      'endReason': conversation.endReason.name,
      'elderTurns': conversation.elderTurns,
      if (turns != null)
        'turns': [
          for (final turn in turns)
            {'role': turn.role.name, 'text': turn.text},
        ],
    });
  }
}
