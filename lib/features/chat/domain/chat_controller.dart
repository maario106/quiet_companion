import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_state.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _geminiService;

  ChatController(this._geminiService) : super(const ChatState());

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    state = state.copyWith(
      status: ChatStatus.pensando,
      responseAI: 'Pensando...',
    );

    try {
      final response = await _geminiService.sendMessage(message);

      state = state.copyWith(
        status: ChatStatus.inicial,
        responseAI: response,
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'Ups, ha habido un problema de conexión. ¿Puedes repetir?',
      );
    }
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  final geminiService = GeminiService();
  return ChatController(geminiService);
});