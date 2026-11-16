import 'package:cloud_functions/cloud_functions.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';

/// Envía la conversación terminada a closeConversation, que la descarta tras analizarla.
class CloudConversationCloser implements ConversationCloser {
  const CloudConversationCloser(this._functions);

  final FirebaseFunctions _functions;

  /// El análisis tarda más que una síntesis.
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
