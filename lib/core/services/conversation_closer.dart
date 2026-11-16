import 'package:flutter/foundation.dart';

/// Quién habla en un turno. Los nombres viajan tal cual a la callable.
enum ConversationRole { elder, assistant }

/// Un turno de la conversación en curso. Solo vive en memoria.
class ConversationTurn {
  const ConversationTurn({
    required this.role,
    required this.text,
    required this.at,
  });

  final ConversationRole role;
  final String text;
  final DateTime at;
}

/// Por qué terminó una conversación.
enum ConversationEndReason { inactivity, background }

/// Una conversación terminada, lista para analizarse.
class ClosedConversation {
  const ClosedConversation({
    required this.startedAt,
    required this.endedAt,
    required this.endReason,
    required this.elderTurns,
    this.turns,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final ConversationEndReason endReason;
  final int elderTurns;

  /// null bajo el umbral de turnos: el texto no sale del teléfono.
  final List<ConversationTurn>? turns;
}

/// Entrega una conversación terminada para su análisis, sin que el mayor lo note.
abstract interface class ConversationCloser {
  Future<void> close(ClosedConversation conversation);
}

/// No envía nada; para los tests que no miran el cierre.
class NoopConversationCloser implements ConversationCloser {
  const NoopConversationCloser();

  @override
  Future<void> close(ClosedConversation conversation) async {
    // Solo metadatos, nunca el texto.
    debugPrint('[CONV] cierre sin enviar: ${conversation.endReason.name}, '
        '${conversation.elderTurns} turnos del mayor');
  }
}
