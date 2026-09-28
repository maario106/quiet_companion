/// Parámetros de la frontera de una conversación (ADR-0028).
///
/// El plazo de inactividad no está aquí: es configurable por conversación
/// (`ConversationSettings`, ADR-0034).
library;

/// Por debajo de esto, se registra que hubo conversación pero no se envía
/// texto a analizar: un "hola, adiós" no tiene ánimo que medir y no justifica
/// sacar lo dicho del teléfono.
const int kMinElderTurnsForAnalysis = 3;
