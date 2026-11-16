enum ChatStatus {
  initial,
  listening,
  thinking,
  talking,
  error
}

/// Cómo dice el mayor sus turnos; la voz es el modo de partida.
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

  /// Si se puede enviar un turno escrito: no con otro en vuelo ni con el micrófono abierto.
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
