import 'package:flutter/foundation.dart';

/// Quién habla en un turno. Los nombres viajan tal cual a la callable.
enum ConversationRole { elder, assistant }

/// Un turno de la conversación en curso. Solo vive en memoria (ADR-0028):
/// nunca se escribe en disco ni en Firestore.
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

  /// null bajo el umbral de turnos: solo se registra la actividad y el texto no
  /// sale del teléfono.
  final List<ConversationTurn>? turns;
}

/// Entrega una conversación terminada para su análisis (`closeConversation`,
/// ADR-0029). Quien llama no espera ni enseña nada: el mayor no debe notar el
/// cierre.
abstract interface class ConversationCloser {
  Future<void> close(ClosedConversation conversation);
}

/// Implementación que no envía nada. Sirve mientras la callable no está
/// cableada y en los tests que no miran el cierre.
class NoopConversationCloser implements ConversationCloser {
  const NoopConversationCloser();

  @override
  Future<void> close(ClosedConversation conversation) async {
    // Solo metadatos: el texto de una conversación no va nunca a un registro.
    debugPrint('[CONV] cierre sin enviar: ${conversation.endReason.name}, '
        '${conversation.elderTurns} turnos del mayor');
  }
}
