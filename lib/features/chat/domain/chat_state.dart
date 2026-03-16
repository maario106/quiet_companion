enum ChatStatus {
  inicial,
  escuchando,
  pensando,
  hablando,
  error
}

class ChatState {
  final String responseAI;
  final ChatStatus status;

  const ChatState({
    this.responseAI = 'Hola! ¿De qué quieres que hablemos hoy?',
    this.status = ChatStatus.inicial,
  });

  ChatState copyWith({
    String? responseAI,
    ChatStatus? status,
  }) {
    return ChatState(
      responseAI: responseAI ?? this.responseAI,
      status: status ?? this.status,
    );
  }
}