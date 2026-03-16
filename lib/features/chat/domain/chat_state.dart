enum ChatStatus {
  initial,
  listening,
  thinking,
  talking,
  error
}

class ChatState {
  final String responseAI;
  final ChatStatus status;
  final String userMessage;

  const ChatState({
    this.responseAI = 'Hola! ¿De qué quieres que hablemos hoy?',
    this.status = ChatStatus.initial,
    this.userMessage = '',
  });

  ChatState copyWith({
    String? responseAI,
    ChatStatus? status,
    String? userMessage,
  }) {
    return ChatState(
      responseAI: responseAI ?? this.responseAI,
      status: status ?? this.status,
      userMessage: userMessage ?? this.userMessage,
    );
  }
}