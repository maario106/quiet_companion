enum ChatStatus {
  initial,
  listening,
  thinking,
  talking,
  error
}

/// Cómo dice el mayor sus turnos (ADR-0035). La voz es el modo de partida;
/// el teclado es para quien no quiere o no puede hablar en ese momento.
enum InputMode { voice, keyboard }

class ChatState {
  final String responseAI;
  final ChatStatus status;
  final String userMessage;
  final InputMode inputMode;

  const ChatState({
    this.responseAI = 'Hola! ¿De qué quieres que hablemos hoy?',
    this.status = ChatStatus.initial,
    this.userMessage = '',
    this.inputMode = InputMode.voice,
  });

  /// Si se puede enviar ahora un turno escrito: no con otro turno esperando
  /// respuesta ni con el micrófono abierto. Con la voz de la app sonando sí,
  /// porque el turno nuevo la calla. La pantalla y el controlador preguntan
  /// lo mismo aquí para no acabar decidiéndolo de dos maneras.
  bool get acceptsTypedTurn =>
      status != ChatStatus.thinking && status != ChatStatus.listening;

  ChatState copyWith({
    String? responseAI,
    ChatStatus? status,
    String? userMessage,
    InputMode? inputMode,
  }) {
    return ChatState(
      responseAI: responseAI ?? this.responseAI,
      status: status ?? this.status,
      userMessage: userMessage ?? this.userMessage,
      inputMode: inputMode ?? this.inputMode,
    );
  }
}
