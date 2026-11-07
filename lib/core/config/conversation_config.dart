/// Parámetros de la frontera de una conversación (ADR-0028).
///
/// El plazo de inactividad no está aquí: es configurable por conversación
/// (`ConversationSettings`, ADR-0034).
library;

/// Por debajo de esto, se registra que hubo conversación pero no se envía
/// texto a analizar: un "hola, adiós" no tiene ánimo que medir y no justifica
/// sacar lo dicho del teléfono.
const int kMinElderTurnsForAnalysis = 3;

/// Turnos de la conversación en curso que viajan con cada mensaje a
/// `chatTurn`. Espejo de `MAX_TURNS` del servidor, que rechaza más. Es par:
/// los turnos se apuntan por parejas y el recorte empieza siempre en el mayor.
const int kChatHistoryMaxTurns = 200;
